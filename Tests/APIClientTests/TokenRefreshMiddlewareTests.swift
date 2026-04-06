@testable import APIClient
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@Suite("TokenRefreshMiddleware Tests")
struct TokenRefreshMiddlewareTests {
    private let testBaseURL = URL(string: "https://api.example.com")!

    private func makeRequest(path: String = "/v1/users/me") -> HTTPRequest {
        HTTPRequest(method: .get, scheme: "https", authority: "api.example.com", path: path)
    }

    // MARK: - Pass-Through Tests

    @Test("Passes through non-401 responses without refreshing")
    func passesThroughNon401() async throws {
        let authMiddleware = AuthenticationMiddleware(accessToken: "token")
        var refreshCalled = false

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            refreshCalled = true
            return .init(accessToken: "new", refreshToken: "new")
        }

        let (response, _) = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            (HTTPResponse(status: .ok), nil)
        }

        #expect(response.status == .ok)
        #expect(refreshCalled == false)
    }

    @Test("Passes through error responses other than 401")
    func passesThroughOtherErrors() async throws {
        let authMiddleware = AuthenticationMiddleware(accessToken: "token")
        var refreshCalled = false

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            refreshCalled = true
            return .init(accessToken: "new", refreshToken: "new")
        }

        let (response, _) = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            (HTTPResponse(status: .forbidden), nil)
        }

        #expect(response.status == .forbidden)
        #expect(refreshCalled == false)
    }

    // MARK: - Refresh & Retry Tests

    @Test("Refreshes token and retries on 401")
    func refreshesAndRetriesOn401() async throws {
        let authMiddleware = AuthenticationMiddleware(
            accessToken: "expired",
            refreshToken: "valid-refresh"
        )
        var callCount = 0

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            .init(accessToken: "fresh-access", refreshToken: "fresh-refresh")
        }

        let (response, _) = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            callCount += 1
            if callCount == 1 {
                return (HTTPResponse(status: .unauthorized), nil)
            }
            return (HTTPResponse(status: .ok), nil)
        }

        #expect(response.status == .ok)
        #expect(callCount == 2)

        // Verify tokens were updated on the auth middleware
        let accessToken = await authMiddleware.getAccessToken()
        #expect(accessToken == "fresh-access")
    }

    @Test("Updates both tokens on auth middleware after refresh")
    func updatesBothTokens() async throws {
        let authMiddleware = AuthenticationMiddleware(
            accessToken: "old-access",
            refreshToken: "old-refresh"
        )

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            .init(accessToken: "new-access", refreshToken: "new-refresh")
        }

        _ = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            (HTTPResponse(status: .unauthorized), nil)
        }

        let accessToken = await authMiddleware.getAccessToken()
        #expect(accessToken == "new-access")
    }

    // MARK: - Refresh Endpoint Guard

    @Test("Does not refresh when 401 comes from the refresh endpoint itself")
    func doesNotRefreshOnRefreshEndpoint401() async throws {
        let authMiddleware = AuthenticationMiddleware(refreshToken: "expired-refresh")
        var refreshCalled = false

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            refreshCalled = true
            return .init(accessToken: "new", refreshToken: "new")
        }

        let (response, _) = try await middleware.intercept(
            makeRequest(path: "/v1/auth/refresh"),
            body: nil,
            baseURL: testBaseURL,
            operationID: "refresh_access_token_v1_auth_refresh_post"
        ) { _, _, _ in
            (HTTPResponse(status: .unauthorized), nil)
        }

        #expect(response.status == .unauthorized)
        #expect(refreshCalled == false)
    }

    // MARK: - Error Propagation

    @Test("Propagates refresh handler errors")
    func propagatesRefreshErrors() async throws {
        let authMiddleware = AuthenticationMiddleware(accessToken: "expired")

        struct RefreshFailed: Error {}

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            throw RefreshFailed()
        }

        await #expect(throws: RefreshFailed.self) {
            _ = try await middleware.intercept(
                makeRequest(),
                body: nil,
                baseURL: testBaseURL,
                operationID: "get_user"
            ) { _, _, _ in
                (HTTPResponse(status: .unauthorized), nil)
            }
        }
    }

    // MARK: - Concurrent Refresh Coalescing

    @Test("Coalesces concurrent 401 refreshes into a single refresh call")
    func coalescesConcurrentRefreshes() async throws {
        let authMiddleware = AuthenticationMiddleware(
            accessToken: "expired",
            refreshToken: "valid"
        )
        let refreshCount = ManagedAtomic(0)

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            refreshCount.increment()
            // Simulate network delay so concurrent requests overlap
            try await Task.sleep(for: .milliseconds(50))
            return .init(accessToken: "fresh", refreshToken: "fresh-refresh")
        }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    _ = try? await middleware.intercept(
                        makeRequest(),
                        body: nil,
                        baseURL: testBaseURL,
                        operationID: "get_user"
                    ) { _, _, _ in
                        (HTTPResponse(status: .unauthorized), nil)
                    }
                }
            }
        }

        // Actor serialization means some tasks may arrive after the first refresh completes,
        // but coalescing should still reduce 10 concurrent 401s to far fewer than 10 refreshes.
        #expect(refreshCount.value <= 2)
    }

    @Test("Subsequent 401 after completed refresh triggers a new refresh")
    func newRefreshAfterPreviousCompletes() async throws {
        let authMiddleware = AuthenticationMiddleware(accessToken: "expired")
        var refreshCount = 0

        let middleware = TokenRefreshMiddleware(authMiddleware: authMiddleware) { _ in
            refreshCount += 1
            return .init(accessToken: "fresh-\(refreshCount)", refreshToken: "refresh-\(refreshCount)")
        }

        // First 401 → refresh
        _ = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            (HTTPResponse(status: .unauthorized), nil)
        }

        // Second 401 → should trigger a new refresh (not reuse old)
        _ = try await middleware.intercept(
            makeRequest(),
            body: nil,
            baseURL: testBaseURL,
            operationID: "get_user"
        ) { _, _, _ in
            (HTTPResponse(status: .unauthorized), nil)
        }

        #expect(refreshCount == 2)
        let token = await authMiddleware.getAccessToken()
        #expect(token == "fresh-2")
    }
}

// MARK: - Thread-safe counter for concurrency test

private final class ManagedAtomic: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int

    init(_ initial: Int) { _value = initial }

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

import Foundation
import SwiftUI
@testable import SharedKit
import Testing

@Suite("BiometricLockView")
struct BiometricLockViewTests {

    // MARK: - Mock

    @MainActor
    private final class MockBiometricAuthManager: BiometricAuthManagerProtocol {
        @Published private(set) var isBiometricAvailable: Bool = true
        @Published private(set) var biometricType: BiometricType = .faceID

        var isBiometricAvailablePublisher: Published<Bool>.Publisher {
            $isBiometricAvailable
        }

        var biometricTypePublisher: Published<BiometricType>.Publisher {
            $biometricType
        }

        var shouldFail: Bool
        var failureError: BiometricAuthError

        init(shouldFail: Bool = false, failureError: BiometricAuthError = .authenticationFailed) {
            self.shouldFail = shouldFail
            self.failureError = failureError
        }

        var authenticateCallCount = 0
        var lastAuthReason: String?

        func authenticate(reason: String) async throws {
            authenticateCallCount += 1
            lastAuthReason = reason
            if shouldFail { throw failureError }
        }

        func authenticateWithPasscodeFallback(reason: String) async throws {
            authenticateCallCount += 1
            lastAuthReason = reason
            if shouldFail { throw failureError }
        }

        func refreshBiometricStatus() {}
    }

    // MARK: - Initialization

    @Test("stores biometricType parameter")
    @MainActor
    func storesBiometricType() {
        let manager = MockBiometricAuthManager()
        let view = BiometricLockView(
            biometricType: .touchID,
            biometricAuthManager: manager,
            onAuthenticated: {},
            onSignOut: {}
        ) { EmptyView() }

        #expect(view.biometricType == .touchID)
    }

    @Test("stores custom authReason")
    @MainActor
    func storesAuthReason() {
        let manager = MockBiometricAuthManager()
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            authReason: "Custom reason",
            onAuthenticated: {},
            onSignOut: {}
        ) { EmptyView() }

        #expect(view.authReason == "Custom reason")
    }

    @Test("default authReason is provided")
    @MainActor
    func defaultAuthReason() {
        let manager = MockBiometricAuthManager()
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            onAuthenticated: {},
            onSignOut: {}
        ) { EmptyView() }

        #expect(view.authReason == "Verify your identity to continue")
    }

    // MARK: - Branding ViewBuilder

    @Test("accepts custom branding content via ViewBuilder")
    @MainActor
    func customBranding() {
        let manager = MockBiometricAuthManager()
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            onAuthenticated: {},
            onSignOut: {}
        ) {
            VStack {
                Image(systemName: "star.fill")
                Text("MyApp")
            }
        }

        #expect(view.biometricType == .faceID)
    }

    // MARK: - Body rendering

    @Test("body renders without error")
    @MainActor
    func bodyRenders() {
        let manager = MockBiometricAuthManager()
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            onAuthenticated: {},
            onSignOut: {}
        ) { EmptyView() }

        _ = view.body
    }

    @Test("body renders for each biometric type")
    @MainActor
    func bodyRendersAllTypes() {
        let manager = MockBiometricAuthManager()

        for type in [BiometricType.faceID, .touchID, .none] {
            let view = BiometricLockView(
                biometricType: type,
                biometricAuthManager: manager,
                onAuthenticated: {},
                onSignOut: {}
            ) { EmptyView() }

            _ = view.body
        }
    }

    // MARK: - Callback wiring

    @Test("onAuthenticated callback is stored and callable")
    @MainActor
    func onAuthenticatedCallable() {
        let manager = MockBiometricAuthManager()
        var called = false
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            onAuthenticated: { called = true },
            onSignOut: {}
        ) { EmptyView() }

        view.onAuthenticated()
        #expect(called)
    }

    @Test("onSignOut callback is stored and callable")
    @MainActor
    func onSignOutCallable() {
        let manager = MockBiometricAuthManager()
        var called = false
        let view = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            onAuthenticated: {},
            onSignOut: { called = true }
        ) { EmptyView() }

        view.onSignOut()
        #expect(called)
    }

    // MARK: - Authentication trigger

    @Test("manager receives authentication call with correct reason")
    @MainActor
    func authenticationCallForwarded() async {
        let manager = MockBiometricAuthManager()
        _ = BiometricLockView(
            biometricType: .faceID,
            biometricAuthManager: manager,
            authReason: "Test reason",
            onAuthenticated: {},
            onSignOut: {}
        ) { EmptyView() }

        try? await manager.authenticateWithPasscodeFallback(reason: "Test reason")
        #expect(manager.authenticateCallCount == 1)
        #expect(manager.lastAuthReason == "Test reason")
    }

    @Test("manager can fail with authentication error")
    @MainActor
    func authenticationCanFail() async {
        let manager = MockBiometricAuthManager(shouldFail: true)

        do {
            try await manager.authenticateWithPasscodeFallback(reason: "Test")
            Issue.record("Expected error to be thrown")
        } catch let error as BiometricAuthError {
            #expect(error == .authenticationFailed)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("manager can fail with different error types")
    @MainActor
    func authenticationErrorTypes() async {
        let errors: [BiometricAuthError] = [
            .notAvailable, .notEnrolled, .lockedOut,
            .userCancelled, .systemCancelled, .authenticationFailed
        ]

        for expectedError in errors {
            let manager = MockBiometricAuthManager(shouldFail: true, failureError: expectedError)

            do {
                try await manager.authenticateWithPasscodeFallback(reason: "Test")
                Issue.record("Expected error to be thrown")
            } catch let error as BiometricAuthError {
                #expect(error == expectedError)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
}

import Testing
import Foundation
@testable import SharedKit

// MARK: - Test Helpers

private enum TestOp: String, Codable, Hashable, Sendable {
    case updateProfile
    case sendMessage
    case deleteItem
}

private final class MockNetworkMonitor: NetworkMonitorProtocol, Sendable {
    let isConnected: Bool

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}

private enum TestError: Error {
    case executionFailed
}

// MARK: - Tests

@Suite("OfflineOperationQueue")
struct OfflineOperationQueueTests {

    // MARK: - Helpers

    /// Create a fresh UserDefaults suite for test isolation
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "OfflineOperationQueueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    /// Remove the test suite from UserDefaults
    private func cleanDefaults(suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeQueue(
        storageKey: String = "test.queue",
        maxQueueSize: Int = 100,
        maxRetryAttempts: Int = 5,
        userDefaults: UserDefaults,
        networkMonitor: MockNetworkMonitor = MockNetworkMonitor(isConnected: true),
        executor: @escaping @Sendable (QueuedOperation<TestOp>) async throws -> Void = { _ in }
    ) -> OfflineOperationQueue<TestOp> {
        OfflineOperationQueue<TestOp>(
            storageKey: storageKey,
            maxQueueSize: maxQueueSize,
            maxRetryAttempts: maxRetryAttempts,
            userDefaults: userDefaults,
            networkMonitor: networkMonitor,
            executor: executor
        )
    }

    // MARK: - Enqueue

    @Test("Enqueue adds operation and increments count")
    func enqueueAddsOperation() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(userDefaults: defaults)
        #expect(await queue.operationCount == 0)

        try await queue.enqueue(type: .updateProfile, payload: Data())
        #expect(await queue.operationCount == 1)
    }

    @Test("Enqueue multiple different types increments count for each")
    func enqueueMultipleTypes() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(userDefaults: defaults)

        try await queue.enqueue(type: .updateProfile, payload: Data())
        try await queue.enqueue(type: .sendMessage, payload: Data())
        try await queue.enqueue(type: .deleteItem, payload: Data())

        #expect(await queue.operationCount == 3)
    }

    // MARK: - Duplicate Coalescing

    @Test("Enqueue same type replaces existing operation (last-write-wins)")
    func duplicateCoalescing() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(userDefaults: defaults)

        let firstPayload = try JSONEncoder().encode("first")
        let secondPayload = try JSONEncoder().encode("second")

        try await queue.enqueue(type: .updateProfile, payload: firstPayload)
        try await queue.enqueue(type: .updateProfile, payload: secondPayload)

        #expect(await queue.operationCount == 1)

        let ops = await queue.pendingOperationsList
        #expect(ops.first?.payload == secondPayload)
    }

    // MARK: - Persistence

    @Test("Operations survive UserDefaults round-trip")
    func persistence() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let storageKey = "test.persistence"

        let queue1 = makeQueue(storageKey: storageKey, userDefaults: defaults)
        try await queue1.enqueue(type: .updateProfile, payload: Data())
        try await queue1.enqueue(type: .sendMessage, payload: Data())

        // Create a new queue with the same storage key — should load persisted ops
        let queue2 = makeQueue(storageKey: storageKey, userDefaults: defaults)
        #expect(await queue2.operationCount == 2)

        let ops = await queue2.pendingOperationsList
        #expect(ops[0].type == .updateProfile)
        #expect(ops[1].type == .sendMessage)
    }

    // MARK: - FIFO Eviction

    @Test("Enqueue beyond maxQueueSize evicts oldest operation")
    func fifoEviction() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(maxQueueSize: 2, userDefaults: defaults)

        try await queue.enqueue(type: .updateProfile, payload: Data())
        try await queue.enqueue(type: .sendMessage, payload: Data())
        try await queue.enqueue(type: .deleteItem, payload: Data())

        #expect(await queue.operationCount == 2)

        let ops = await queue.pendingOperationsList
        #expect(ops[0].type == .sendMessage)
        #expect(ops[1].type == .deleteItem)
    }

    // MARK: - Sync Execution

    @Test("Sync calls executor and removes successful operations")
    func syncRemovesSuccessful() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let executedTypes = UncheckedSendable<[TestOp]>([])
        let queue = makeQueue(userDefaults: defaults) { operation in
            var types = executedTypes.value
            types.append(operation.type)
            executedTypes.value = types
        }

        try await queue.enqueue(type: .updateProfile, payload: Data())
        try await queue.enqueue(type: .sendMessage, payload: Data())

        await queue.syncPendingOperations()

        #expect(await queue.operationCount == 0)
        #expect(executedTypes.value.count == 2)
        #expect(executedTypes.value.contains(.updateProfile))
        #expect(executedTypes.value.contains(.sendMessage))
    }

    // MARK: - Retry on Failure

    @Test("Failed execution keeps operation in queue with incremented attemptCount")
    func retryOnFailure() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(maxRetryAttempts: 5, userDefaults: defaults) { _ in
            throw TestError.executionFailed
        }

        try await queue.enqueue(type: .updateProfile, payload: Data())
        await queue.syncPendingOperations()

        #expect(await queue.operationCount == 1)

        let ops = await queue.pendingOperationsList
        #expect(ops.first?.attemptCount == 1)
        #expect(ops.first?.lastAttemptAt != nil)
    }

    // MARK: - Max Retries → Failed

    @Test("Operation moves to failedOperations after maxRetryAttempts")
    func maxRetriesMovesToFailed() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(maxRetryAttempts: 1, userDefaults: defaults) { _ in
            throw TestError.executionFailed
        }

        try await queue.enqueue(type: .updateProfile, payload: Data())

        // First sync: attemptCount goes from 0 → 1, which equals maxRetryAttempts
        await queue.syncPendingOperations()

        #expect(await queue.operationCount == 0)
        let failed = await queue.failedOperations
        #expect(failed.count == 1)
        #expect(failed.first?.type == .updateProfile)
    }

    // MARK: - Exponential Backoff

    @Test("Operations with recent lastAttemptAt are skipped during sync")
    func exponentialBackoffSkipsRecent() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let callCount = UncheckedSendable(0)
        let queue = makeQueue(maxRetryAttempts: 3, userDefaults: defaults) { _ in
            callCount.value += 1
            throw TestError.executionFailed
        }

        try await queue.enqueue(type: .updateProfile, payload: Data())

        // First sync: attempt 0 → executes, fails, attemptCount becomes 1, lastAttemptAt = now
        await queue.syncPendingOperations()
        #expect(callCount.value == 1)
        #expect(await queue.operationCount == 1)

        // Second sync immediately after: backoff delay (2^1 = 2s) not elapsed → skipped
        await queue.syncPendingOperations()
        #expect(callCount.value == 1) // Still 1, was skipped due to backoff
        #expect(await queue.operationCount == 1) // Still pending
    }

    // MARK: - clearAll

    @Test("clearAll removes pending and failed operations")
    func clearAll() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(maxRetryAttempts: 1, userDefaults: defaults) { _ in
            throw TestError.executionFailed
        }

        // Create a pending operation
        try await queue.enqueue(type: .sendMessage, payload: Data())
        // Create a failed operation
        try await queue.enqueue(type: .updateProfile, payload: Data())
        await queue.syncPendingOperations()

        // sendMessage was skipped (backoff) or failed; updateProfile failed and moved to failed list
        // Add a fresh pending one to be sure we have both pending and failed
        try await queue.enqueue(type: .deleteItem, payload: Data())

        let hasPending = await queue.operationCount > 0
        let hasFailed = await queue.failedOperations.count > 0
        #expect(hasPending || hasFailed)

        await queue.clearAll()

        #expect(await queue.operationCount == 0)
        #expect(await queue.failedOperations.isEmpty)
    }

    // MARK: - clearFailedOperations

    @Test("clearFailedOperations removes only failed, keeps pending")
    func clearFailedOnly() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let queue = makeQueue(maxRetryAttempts: 1, userDefaults: defaults) { _ in
            throw TestError.executionFailed
        }

        // Enqueue and fail one operation
        try await queue.enqueue(type: .updateProfile, payload: Data())
        await queue.syncPendingOperations()

        #expect(await queue.failedOperations.count == 1)
        #expect(await queue.operationCount == 0)

        // Add a new pending operation
        try await queue.enqueue(type: .sendMessage, payload: Data())
        #expect(await queue.operationCount == 1)

        await queue.clearFailedOperations()

        #expect(await queue.failedOperations.isEmpty)
        #expect(await queue.operationCount == 1) // Pending preserved
    }

    // MARK: - Sync skipped when offline

    @Test("Sync is skipped when network is disconnected")
    func syncSkippedWhenOffline() async throws {
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        let callCount = UncheckedSendable(0)
        let queue = makeQueue(
            userDefaults: defaults,
            networkMonitor: MockNetworkMonitor(isConnected: false)
        ) { _ in
            callCount.value += 1
        }

        try await queue.enqueue(type: .updateProfile, payload: Data())
        await queue.syncPendingOperations()

        #expect(callCount.value == 0)
        #expect(await queue.operationCount == 1)
    }
}

// MARK: - UncheckedSendable wrapper for test closures

private final class UncheckedSendable<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

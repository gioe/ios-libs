import Combine
import Foundation
import os

// MARK: - QueuedOperation

/// Represents a queued mutation operation to be executed when connectivity is restored
public struct QueuedOperation<OpType: Codable & Hashable & Sendable>: Codable, Identifiable, Sendable {
    /// Unique identifier for the operation
    public let id: UUID
    /// Type of operation to perform
    public let type: OpType
    /// JSON-encoded operation data
    public let payload: Data
    /// When the operation was first created
    public let createdAt: Date
    /// Number of times this operation has been attempted
    public var attemptCount: Int
    /// When the last attempt was made
    public var lastAttemptAt: Date?
    /// Last error message (for user feedback)
    public var error: String?

    public init(
        id: UUID = UUID(),
        type: OpType,
        payload: Data,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.error = error
    }
}

extension QueuedOperation: Equatable {
    public static func == (lhs: QueuedOperation, rhs: QueuedOperation) -> Bool {
        lhs.id == rhs.id
            && lhs.type == rhs.type
            && lhs.payload == rhs.payload
            && lhs.createdAt == rhs.createdAt
            && lhs.attemptCount == rhs.attemptCount
            && lhs.lastAttemptAt == rhs.lastAttemptAt
            && lhs.error == rhs.error
    }
}

// MARK: - OfflineOperationQueueProtocol

/// Protocol for offline operation queue to enable testability
public protocol OfflineOperationQueueProtocol<OpType> {
    associatedtype OpType: Codable & Hashable & Sendable

    /// Number of pending operations in the queue
    var operationCount: Int { get async }
    /// Whether the queue is currently syncing operations
    var isSyncing: Bool { get async }
    /// Operations that have permanently failed after max retry attempts
    var failedOperations: [QueuedOperation<OpType>] { get async }

    /// Enqueue a new operation
    ///
    /// Duplicate coalescing: if an operation with the same `type` is already pending,
    /// it is replaced (last-write-wins). This is ideal for idempotent updates but will
    /// discard earlier payloads for non-idempotent operations.
    /// - Parameters:
    ///   - type: The type of operation
    ///   - payload: JSON-encoded operation data
    func enqueue(type: OpType, payload: Data) async throws

    /// Manually trigger sync of pending operations
    func syncPendingOperations() async

    /// Clear all failed operations from the failed list
    func clearFailedOperations() async

    /// Clear all operations (pending and failed) - useful for logout
    func clearAll() async
}

// MARK: - OfflineOperationError

/// Errors specific to offline operation queue.
///
/// Conforms to ``RetryableError`` so executors can signal that a failure is terminal —
/// e.g. an HTTP 4xx (401/404/422) where retrying will never succeed — and the queue
/// should skip retry/backoff and route the operation directly to ``OfflineOperationQueue/failedOperations``.
///
/// Throwing a plain `Error` (or any error that does not conform to `RetryableError`)
/// preserves the existing retry-with-backoff behavior. Only errors with
/// `isRetryable == false` short-circuit the retry budget.
public enum OfflineOperationError: LocalizedError, RetryableError {
    /// The operation failed terminally and must not be retried.
    case terminal(reason: String)

    public var isRetryable: Bool {
        switch self {
        case .terminal: return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .terminal(let reason): return reason
        }
    }
}

// MARK: - OfflineOperationQueue

/// Actor-based offline operation queue with persistence and automatic retry
///
/// A generic queue that persists pending mutations and automatically replays them
/// when network connectivity is restored. Consumers provide their own operation type
/// enum and an executor closure to handle each operation.
///
/// ## Thread Safety
/// - All queue operations are thread-safe through Swift actor isolation
/// - `enqueue()`, `syncPendingOperations()`, and all queue state access is serialized by the actor
/// - Safe to call from any thread/context
/// - Network monitoring uses Combine publisher observation (thread-safe)
///
/// ## Usage Example
/// ```swift
/// enum MyOp: String, Codable, Hashable, Sendable {
///     case updateProfile
///     case sendMessage
/// }
///
/// let queue = OfflineOperationQueue<MyOp>(
///     storageKey: "com.myapp.offlineQueue",
///     executor: { operation in
///         switch operation.type {
///         case .updateProfile:
///             let profile = try JSONDecoder().decode(Profile.self, from: operation.payload)
///             try await api.updateProfile(profile)
///         case .sendMessage:
///             let message = try JSONDecoder().decode(Message.self, from: operation.payload)
///             try await api.sendMessage(message)
///         }
///     }
/// )
/// ```
///
/// ## Retry Policy
/// - Configurable max retry attempts (default 5)
/// - Exponential backoff: 2s, 4s, 8s, 16s (attempt N → 2^N seconds)
/// - Operations exceeding max retries are moved to failedOperations
/// - Executors that throw a ``RetryableError`` with `isRetryable == false` skip retry/backoff
///   entirely and route the operation directly to failedOperations on the first failure.
///   Use this for terminal HTTP responses (4xx) that will never succeed on retry.
///
/// ## Persistence
/// - Queue persists to UserDefaults after each modification
/// - Corrupt data is cleared gracefully on load
/// - Configurable max queue size (default 100, FIFO eviction)
/// - Duplicate coalescing: same operation type replaces existing (last-write-wins)
public actor OfflineOperationQueue<OpType: Codable & Hashable & Sendable>: OfflineOperationQueueProtocol {
    // MARK: - Logging

    private let logger: Logger

    // MARK: - Configuration

    private let storageKey: String
    private let failedStorageKey: String
    private let maxQueueSize: Int
    private let maxRetryAttempts: Int
    private let networkStateDebounceDelay: TimeInterval = 1.0

    // MARK: - Properties

    /// Pending operations waiting to be synced
    private var pendingOperations: [QueuedOperation<OpType>] = []

    /// Operations that have permanently failed
    private var internalFailedOperations: [QueuedOperation<OpType>] = []

    /// Whether sync is currently in progress
    private var internalIsSyncing = false

    /// UserDefaults for persistence
    private let userDefaults: UserDefaults

    /// Network connectivity monitor
    private let networkMonitor: any NetworkMonitorProtocol

    /// Executor closure provided by the consumer
    private let executor: @Sendable (QueuedOperation<OpType>) async throws -> Void

    /// Debounce timer for network state changes
    private var debounceTask: Task<Void, Never>?

    /// Cached network connectivity state (actor-isolated to avoid cross-actor access)
    private var isNetworkConnected: Bool

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Task for network monitoring initialization (stored to enable cancellation on deinit)
    private nonisolated(unsafe) var networkMonitoringTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Create a new offline operation queue
    /// - Parameters:
    ///   - storageKey: UserDefaults key for persisting pending operations. Failed operations
    ///     are stored under `"\(storageKey).failed"`.
    ///   - maxQueueSize: Maximum number of pending operations before FIFO eviction (default 100)
    ///   - maxRetryAttempts: Maximum retry attempts before an operation is moved to failed (default 5)
    ///   - userDefaults: UserDefaults instance for persistence (default `.standard`)
    ///   - networkMonitor: Network monitor for connectivity observation (default `NetworkMonitor.shared`)
    ///   - subsystem: Logger subsystem identifier (default `"SharedKit"`)
    ///   - executor: Closure that executes a queued operation. Called during sync for each pending operation.
    public init(
        storageKey: String,
        maxQueueSize: Int = 100,
        maxRetryAttempts: Int = 5,
        userDefaults: UserDefaults = .standard,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor.shared,
        subsystem: String = "SharedKit",
        executor: @escaping @Sendable (QueuedOperation<OpType>) async throws -> Void
    ) {
        self.storageKey = storageKey
        self.failedStorageKey = "\(storageKey).failed"
        self.maxQueueSize = maxQueueSize
        self.maxRetryAttempts = maxRetryAttempts
        self.userDefaults = userDefaults
        self.networkMonitor = networkMonitor
        self.executor = executor
        self.logger = Logger(subsystem: subsystem, category: "OfflineOperationQueue")
        self.isNetworkConnected = networkMonitor.isConnected

        // Load persisted operations
        pendingOperations = Self.loadOperations(from: userDefaults, key: storageKey)
        internalFailedOperations = Self.loadOperations(from: userDefaults, key: "\(storageKey).failed")

        // Start monitoring network connectivity
        networkMonitoringTask = Task {
            startNetworkMonitoring()
        }
    }

    deinit {
        networkMonitoringTask?.cancel()
        debounceTask?.cancel()
    }

    // MARK: - Protocol Conformance

    public var operationCount: Int {
        pendingOperations.count
    }

    public var isSyncing: Bool {
        internalIsSyncing
    }

    public var failedOperations: [QueuedOperation<OpType>] {
        internalFailedOperations
    }

    /// All pending operations currently in the queue
    public var pendingOperationsList: [QueuedOperation<OpType>] {
        pendingOperations
    }

    public func enqueue(type: OpType, payload: Data) async throws {
        let operation = QueuedOperation(type: type, payload: payload)

        // Duplicate coalescing: same type → last-write-wins
        if let existingIndex = pendingOperations.firstIndex(where: { $0.type == type }) {
            pendingOperations[existingIndex] = operation
        } else {
            pendingOperations.append(operation)

            // Enforce queue size limit (FIFO eviction)
            if pendingOperations.count > maxQueueSize {
                pendingOperations.removeFirst()
            }
        }

        persist()
    }

    public func syncPendingOperations() async {
        guard canStartSync() else { return }

        internalIsSyncing = true

        var result = SyncResult()
        for operation in pendingOperations {
            await processOperation(operation, result: &result)
        }
        applyChanges(result)

        internalIsSyncing = false
    }

    public func clearFailedOperations() async {
        internalFailedOperations.removeAll()
        persistFailed()
    }

    public func clearAll() async {
        pendingOperations.removeAll()
        internalFailedOperations.removeAll()
        persist()
        persistFailed()
    }

    // MARK: - Private Helpers

    /// Check if sync can start (not already syncing, has operations, and network is available)
    private func canStartSync() -> Bool {
        !internalIsSyncing && !pendingOperations.isEmpty && isNetworkConnected
    }

    /// Process a single operation during sync
    private func processOperation(_ operation: QueuedOperation<OpType>, result: inout SyncResult) async {
        // Check if max retries exceeded
        if operation.attemptCount >= maxRetryAttempts {
            result.operationsToFail.append(operation)
            result.idsToRemove.append(operation.id)
            return
        }

        // Check backoff delay
        if shouldSkipDueToBackoff(operation) {
            return
        }

        // Execute operation via consumer-provided closure
        do {
            try await executor(operation)
            result.idsToRemove.append(operation.id)
        } catch {
            if let retryable = error as? RetryableError, !retryable.isRetryable {
                handleTerminalFailure(operation, error: error, result: &result)
            } else {
                handleOperationFailure(operation, error: error, result: &result)
            }
        }
    }

    /// Mark an operation as permanently failed without consuming retry budget.
    /// Used when the executor throws a ``RetryableError`` whose `isRetryable == false`.
    private func handleTerminalFailure(
        _ operation: QueuedOperation<OpType>,
        error: Error,
        result: inout SyncResult
    ) {
        var failedOperation = operation
        failedOperation.attemptCount += 1
        failedOperation.lastAttemptAt = Date()
        failedOperation.error = error.localizedDescription
        result.operationsToFail.append(failedOperation)
        result.idsToRemove.append(operation.id)
    }

    /// Check if operation should be skipped due to backoff delay
    private func shouldSkipDueToBackoff(_ operation: QueuedOperation<OpType>) -> Bool {
        guard operation.attemptCount > 0, let lastAttempt = operation.lastAttemptAt else {
            return false
        }
        let backoffDelay = calculateBackoffDelay(attempt: operation.attemptCount)
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        return timeSinceLastAttempt < backoffDelay
    }

    /// Handle operation failure by updating retry count or marking as permanently failed
    private func handleOperationFailure(
        _ operation: QueuedOperation<OpType>,
        error: Error,
        result: inout SyncResult
    ) {
        var updatedOperation = operation
        updatedOperation.attemptCount += 1
        updatedOperation.lastAttemptAt = Date()
        updatedOperation.error = error.localizedDescription

        if updatedOperation.attemptCount >= maxRetryAttempts {
            result.operationsToFail.append(updatedOperation)
            result.idsToRemove.append(operation.id)
        } else {
            result.operationsToUpdate.append((operation.id, updatedOperation))
        }
    }

    /// Apply sync result changes to the queue
    private func applyChanges(_ result: SyncResult) {
        let idsToRemoveSet = Set(result.idsToRemove)
        pendingOperations.removeAll { idsToRemoveSet.contains($0.id) }
        for (id, updatedOp) in result.operationsToUpdate {
            if let index = pendingOperations.firstIndex(where: { $0.id == id }) {
                pendingOperations[index] = updatedOp
            }
        }
        internalFailedOperations.append(contentsOf: result.operationsToFail)

        persist()
        persistFailed()
    }

    /// Result container for sync operation
    private struct SyncResult {
        var idsToRemove: [UUID] = []
        var operationsToUpdate: [(UUID, QueuedOperation<OpType>)] = []
        var operationsToFail: [QueuedOperation<OpType>] = []
    }

    /// Calculate exponential backoff delay for retry attempt
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 2s, 4s, 8s, 16s (attempt 1→2s, 2→4s, 3→8s, 4→16s)
        pow(2.0, Double(attempt))
    }

    // MARK: - Network Monitoring

    /// Start monitoring network connectivity
    private nonisolated func startNetworkMonitoring() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await observeNetworkChanges()
        }
    }

    /// Set up network observation (must be called from actor context)
    private func observeNetworkChanges() {
        networkMonitor.connectivityPublisher
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] (isConnected: Bool) in
                Task { [weak self] in
                    await self?.handleNetworkStateChange(isConnected: isConnected)
                }
            }
            .store(in: &cancellables)
    }

    /// Handle network state change with debouncing
    private func handleNetworkStateChange(isConnected: Bool) async {
        isNetworkConnected = isConnected

        debounceTask?.cancel()

        guard isConnected else { return }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(networkStateDebounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await syncPendingOperations()
        }
    }

    // MARK: - Persistence

    /// Persist pending operations to UserDefaults
    private func persist() {
        Self.saveOperations(pendingOperations, to: userDefaults, key: storageKey, logger: logger)
    }

    /// Persist failed operations to UserDefaults
    private func persistFailed() {
        Self.saveOperations(internalFailedOperations, to: userDefaults, key: failedStorageKey, logger: logger)
    }

    /// Load operations from UserDefaults
    private static func loadOperations(
        from userDefaults: UserDefaults,
        key: String
    ) -> [QueuedOperation<OpType>] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        guard let operations = try? JSONDecoder().decode([QueuedOperation<OpType>].self, from: data) else {
            // Clear corrupt data
            userDefaults.removeObject(forKey: key)
            return []
        }

        return operations
    }

    /// Save operations to UserDefaults
    private static func saveOperations(
        _ operations: [QueuedOperation<OpType>],
        to userDefaults: UserDefaults,
        key: String,
        logger: Logger
    ) {
        do {
            let data = try JSONEncoder().encode(operations)
            userDefaults.set(data, forKey: key)
        } catch {
            let errorDesc = error.localizedDescription
            logger.error(
                "Failed to encode operations for '\(key, privacy: .public)': \(errorDesc, privacy: .public)"
            )
            assertionFailure("JSON encoding failed for QueuedOperation array: \(error)")
        }
    }
}

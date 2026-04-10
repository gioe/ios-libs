import Combine
import Foundation
import os

// MARK: - FavoriteOperationType

/// Operation types for the favorites offline queue
public enum FavoriteOperationType: String, Codable, Hashable, Sendable {
    case toggle
}

// MARK: - FavoriteTogglePayload

/// Payload for a queued favorite toggle operation
public struct FavoriteTogglePayload: Codable, Sendable {
    public let comedianId: Int
    public let isFavorite: Bool

    public init(comedianId: Int, isFavorite: Bool) {
        self.comedianId = comedianId
        self.isFavorite = isFavorite
    }
}

// MARK: - FavoritesManagerProtocol

/// Protocol for favorites management with optimistic UI and offline support
@MainActor
public protocol FavoritesManagerProtocol: AnyObject, Sendable {
    /// Returns the current favorite state for a comedian, reflecting optimistic updates
    func isFavorite(comedianId: Int) -> Bool

    /// Sets the initial favorite state for a comedian (e.g., from API load)
    func setInitialState(comedianId: Int, isFavorite: Bool)

    /// Toggles favorite status with optimistic update and offline queue fallback.
    /// Returns the new optimistic state.
    @discardableResult
    func toggleFavorite(comedianId: Int) async -> Bool

    /// Publisher that emits when any comedian's favorite state changes.
    /// Emits the comedian ID that changed.
    var favoriteChanged: AnyPublisher<Int, Never> { get }
}

// MARK: - FavoritesManager

/// Manages comedian favorites with optimistic toggling and offline queue integration.
///
/// When online, calls the API immediately and reverts on failure (showing an error toast).
/// When offline, applies the optimistic update and queues the operation for later sync
/// via `OfflineOperationQueue`.
@MainActor
public final class FavoritesManager: FavoritesManagerProtocol, @unchecked Sendable {
    // MARK: - State

    /// Local cache of favorite states, keyed by comedian ID
    private var favoriteStates: [Int: Bool] = [:]

    /// Subject for broadcasting favorite state changes
    private let favoriteChangedSubject = PassthroughSubject<Int, Never>()

    public var favoriteChanged: AnyPublisher<Int, Never> {
        favoriteChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    private let comedianService: any ComedianServiceProtocol
    private let offlineQueue: OfflineOperationQueue<FavoriteOperationType>
    private let networkMonitor: any NetworkMonitorProtocol
    private let toastManager: (any ToastManagerProtocol)?
    private let logger: Logger

    // MARK: - Initialization

    /// Creates a FavoritesManager.
    ///
    /// - Parameters:
    ///   - comedianService: Service for making favorite API calls
    ///   - networkMonitor: Monitor for checking connectivity before toggling
    ///   - toastManager: Optional toast manager for showing rollback errors
    ///   - offlineQueue: The offline queue for persisting toggles while offline.
    ///     If nil, a default queue is created with the provided comedian service.
    public init(
        comedianService: any ComedianServiceProtocol,
        networkMonitor: any NetworkMonitorProtocol = NetworkMonitor.shared,
        toastManager: (any ToastManagerProtocol)? = nil,
        offlineQueue: OfflineOperationQueue<FavoriteOperationType>? = nil
    ) {
        self.comedianService = comedianService
        self.networkMonitor = networkMonitor
        self.toastManager = toastManager
        self.logger = Logger(subsystem: "SharedKit", category: "FavoritesManager")

        if let offlineQueue {
            self.offlineQueue = offlineQueue
        } else {
            let service = comedianService
            self.offlineQueue = OfflineOperationQueue<FavoriteOperationType>(
                storageKey: "com.sharedkit.favorites.offlineQueue",
                executor: { operation in
                    let payload = try JSONDecoder().decode(FavoriteTogglePayload.self, from: operation.payload)
                    try await service.toggleFavorite(comedianId: payload.comedianId, isFavorite: payload.isFavorite)
                }
            )
        }
    }

    // MARK: - Public API

    public func isFavorite(comedianId: Int) -> Bool {
        favoriteStates[comedianId] ?? false
    }

    public func setInitialState(comedianId: Int, isFavorite: Bool) {
        favoriteStates[comedianId] = isFavorite
    }

    @discardableResult
    public func toggleFavorite(comedianId: Int) async -> Bool {
        let previousValue = favoriteStates[comedianId] ?? false
        let newValue = !previousValue

        // Optimistic update
        favoriteStates[comedianId] = newValue
        favoriteChangedSubject.send(comedianId)

        if networkMonitor.isConnected {
            // Online: call API directly
            do {
                try await comedianService.toggleFavorite(comedianId: comedianId, isFavorite: newValue)
            } catch {
                // Rollback on failure
                favoriteStates[comedianId] = previousValue
                favoriteChangedSubject.send(comedianId)
                logger.error("Failed to toggle favorite for comedian \(comedianId): \(error.localizedDescription)")
                toastManager?.show("Could not update favorite. Please try again.", type: .error)
            }
        } else {
            // Offline: queue for later sync
            do {
                let payload = try JSONEncoder().encode(FavoriteTogglePayload(comedianId: comedianId, isFavorite: newValue))
                try await offlineQueue.enqueue(type: .toggle, payload: payload)
                logger.info("Queued favorite toggle for comedian \(comedianId) (offline)")
            } catch {
                // Rollback if queuing fails
                favoriteStates[comedianId] = previousValue
                favoriteChangedSubject.send(comedianId)
                logger.error("Failed to queue favorite toggle: \(error.localizedDescription)")
                toastManager?.show("Could not save favorite. Please try again.", type: .error)
            }
        }

        return favoriteStates[comedianId] ?? false
    }
}

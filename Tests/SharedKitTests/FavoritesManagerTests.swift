import Combine
import Foundation
@testable import SharedKit
import Testing

// MARK: - Mock Dependencies

private final class MockComedianService: ComedianServiceProtocol, @unchecked Sendable {
    var searchResult: Result<(comedians: [Comedian], hasMore: Bool), Error> = .success((comedians: [], hasMore: false))
    var detailResult: Result<ComedianDetail, Error> = .failure(TestError.notImplemented)
    var toggleFavoriteResult: Result<Void, Error> = .success(())
    var toggleFavoriteCalls: [(comedianId: Int, isFavorite: Bool)] = []

    func searchComedians(filters: ComedianSearchFilters, page: Int, pageSize: Int) async throws -> (comedians: [Comedian], hasMore: Bool) {
        try searchResult.get()
    }

    func getComedian(id: Int) async throws -> ComedianDetail {
        try detailResult.get()
    }

    func toggleFavorite(comedianId: Int, isFavorite: Bool) async throws {
        toggleFavoriteCalls.append((comedianId, isFavorite))
        try toggleFavoriteResult.get()
    }
}

private final class MockNetworkMonitor: NetworkMonitorProtocol, Sendable {
    let isConnected: Bool
    let connectivityPublisher: AnyPublisher<Bool, Never>

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
        self.connectivityPublisher = Just(isConnected).eraseToAnyPublisher()
    }
}

@MainActor
private final class MockToastManager: ToastManagerProtocol, ObservableObject {
    @Published var currentToast: ToastData?
    var showCalls: [(message: String, type: ToastType)] = []

    func show(_ message: String, type: ToastType) {
        showCalls.append((message, type))
        currentToast = ToastData(message: message, type: type)
    }

    func dismiss() {
        currentToast = nil
    }
}

private enum TestError: Error, LocalizedError {
    case networkFailure
    case notImplemented
    var errorDescription: String? {
        switch self {
        case .networkFailure: "Network failure"
        case .notImplemented: "Not implemented"
        }
    }
}

// MARK: - Helpers

private func makeDefaults() -> (UserDefaults, String) {
    let suiteName = "FavoritesManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return (defaults, suiteName)
}

private func cleanDefaults(suiteName: String) {
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
}

private func makeQueue(
    userDefaults: UserDefaults,
    networkMonitor: MockNetworkMonitor = MockNetworkMonitor(isConnected: true),
    service: MockComedianService
) -> OfflineOperationQueue<FavoriteOperationType> {
    OfflineOperationQueue<FavoriteOperationType>(
        storageKey: "test.favorites.queue",
        userDefaults: userDefaults,
        networkMonitor: networkMonitor,
        executor: { operation in
            let payload = try JSONDecoder().decode(FavoriteTogglePayload.self, from: operation.payload)
            try await service.toggleFavorite(comedianId: payload.comedianId, isFavorite: payload.isFavorite)
        }
    )
}

// MARK: - Tests

@Suite("FavoritesManager")
struct FavoritesManagerTests {

    // MARK: - Initial State

    @Test("isFavorite returns false for unknown comedian")
    @MainActor
    func unknownComedianNotFavorite() {
        let service = MockComedianService()
        let manager = FavoritesManager(comedianService: service)
        #expect(manager.isFavorite(comedianId: 42) == false)
    }

    @Test("setInitialState sets favorite state")
    @MainActor
    func setInitialStateSetsState() {
        let service = MockComedianService()
        let manager = FavoritesManager(comedianService: service)
        manager.setInitialState(comedianId: 1, isFavorite: true)
        #expect(manager.isFavorite(comedianId: 1) == true)
    }

    // MARK: - Online Toggle

    @Test("toggleFavorite calls API and updates state when online")
    @MainActor
    func toggleFavoriteOnlineSuccess() async {
        let service = MockComedianService()
        let monitor = MockNetworkMonitor(isConnected: true)
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }
        let queue = makeQueue(userDefaults: defaults, networkMonitor: monitor, service: service)

        let manager = FavoritesManager(
            comedianService: service,
            networkMonitor: monitor,
            offlineQueue: queue
        )
        manager.setInitialState(comedianId: 1, isFavorite: false)

        let result = await manager.toggleFavorite(comedianId: 1)

        #expect(result == true)
        #expect(manager.isFavorite(comedianId: 1) == true)
        #expect(service.toggleFavoriteCalls.count == 1)
        #expect(service.toggleFavoriteCalls[0].comedianId == 1)
        #expect(service.toggleFavoriteCalls[0].isFavorite == true)
    }

    @Test("toggleFavorite rolls back on API failure when online")
    @MainActor
    func toggleFavoriteOnlineFailureRollback() async {
        let service = MockComedianService()
        service.toggleFavoriteResult = .failure(TestError.networkFailure)
        let monitor = MockNetworkMonitor(isConnected: true)
        let toast = MockToastManager()
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }
        let queue = makeQueue(userDefaults: defaults, networkMonitor: monitor, service: service)

        let manager = FavoritesManager(
            comedianService: service,
            networkMonitor: monitor,
            toastManager: toast,
            offlineQueue: queue
        )
        manager.setInitialState(comedianId: 1, isFavorite: true)

        let result = await manager.toggleFavorite(comedianId: 1)

        #expect(result == true) // Rolled back to original
        #expect(manager.isFavorite(comedianId: 1) == true)
        #expect(toast.showCalls.count == 1)
        #expect(toast.showCalls[0].type == .error)
    }

    // MARK: - Offline Queue

    @Test("toggleFavorite queues operation when offline")
    @MainActor
    func toggleFavoriteOfflineQueues() async {
        let service = MockComedianService()
        let monitor = MockNetworkMonitor(isConnected: false)
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }
        let queue = makeQueue(userDefaults: defaults, networkMonitor: monitor, service: service)

        let manager = FavoritesManager(
            comedianService: service,
            networkMonitor: monitor,
            offlineQueue: queue
        )
        manager.setInitialState(comedianId: 5, isFavorite: false)

        let result = await manager.toggleFavorite(comedianId: 5)

        #expect(result == true) // Optimistic update applied
        #expect(manager.isFavorite(comedianId: 5) == true)
        #expect(service.toggleFavoriteCalls.isEmpty) // No API call
        #expect(await queue.operationCount == 1) // Queued
    }

    @Test("queued offline operations sync when queue is triggered")
    @MainActor
    func offlineQueueSyncsOnConnectivity() async {
        let service = MockComedianService()
        let onlineMonitor = MockNetworkMonitor(isConnected: true)
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }

        // Create queue with online monitor so sync works
        let queue = makeQueue(userDefaults: defaults, networkMonitor: onlineMonitor, service: service)

        // Enqueue manually (simulating what happens when offline toggle queues)
        let payload = try! JSONEncoder().encode(FavoriteTogglePayload(comedianId: 7, isFavorite: true))
        try! await queue.enqueue(type: .toggle, payload: payload)
        #expect(await queue.operationCount == 1)

        // Trigger sync
        await queue.syncPendingOperations()

        #expect(await queue.operationCount == 0)
        #expect(service.toggleFavoriteCalls.count == 1)
        #expect(service.toggleFavoriteCalls[0].comedianId == 7)
        #expect(service.toggleFavoriteCalls[0].isFavorite == true)
    }

    // MARK: - Favorite Changed Publisher

    @Test("toggleFavorite emits on favoriteChanged publisher")
    @MainActor
    func toggleEmitsFavoriteChanged() async {
        let service = MockComedianService()
        let monitor = MockNetworkMonitor(isConnected: true)
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }
        let queue = makeQueue(userDefaults: defaults, networkMonitor: monitor, service: service)

        let manager = FavoritesManager(
            comedianService: service,
            networkMonitor: monitor,
            offlineQueue: queue
        )

        var emittedIds: [Int] = []
        let cancellable = manager.favoriteChanged.sink { emittedIds.append($0) }
        defer { cancellable.cancel() }

        manager.setInitialState(comedianId: 3, isFavorite: false)
        await manager.toggleFavorite(comedianId: 3)

        #expect(emittedIds.contains(3))
    }

    // MARK: - Unfavorite

    @Test("toggleFavorite unfavorites a favorited comedian")
    @MainActor
    func toggleFavoriteUnfavorites() async {
        let service = MockComedianService()
        let monitor = MockNetworkMonitor(isConnected: true)
        let (defaults, suite) = makeDefaults()
        defer { cleanDefaults(suiteName: suite) }
        let queue = makeQueue(userDefaults: defaults, networkMonitor: monitor, service: service)

        let manager = FavoritesManager(
            comedianService: service,
            networkMonitor: monitor,
            offlineQueue: queue
        )
        manager.setInitialState(comedianId: 1, isFavorite: true)

        let result = await manager.toggleFavorite(comedianId: 1)

        #expect(result == false)
        #expect(manager.isFavorite(comedianId: 1) == false)
        #expect(service.toggleFavoriteCalls[0].isFavorite == false)
    }
}

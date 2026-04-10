import Combine
import Foundation
@testable import SharedKit
import Testing

// MARK: - Mock Service

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

private enum TestError: Error, LocalizedError {
    case networkFailure
    case notImplemented
    var errorDescription: String? {
        switch self {
        case .networkFailure: return "Network failure"
        case .notImplemented: return "Not implemented"
        }
    }
}

private func makeComedian(id: Int = 1, name: String = "Dave Chappelle", isFavorite: Bool = false) -> Comedian {
    Comedian(
        id: id,
        uuid: "uuid-\(id)",
        name: name,
        imageURL: URL(string: "https://example.com/img/\(id).jpg"),
        showCount: 5,
        isFavorite: isFavorite,
        socialLinks: ComedianSocialLinks(instagramAccount: "dave")
    )
}

private func makeShow(id: Int = 1) -> Show {
    Show(
        id: id,
        comedians: ["Dave Chappelle"],
        venueName: "The Comedy Store",
        date: Date(),
        ticketURL: nil
    )
}

// MARK: - ComedianListViewModel Tests

@Suite("ComedianListViewModel")
struct ComedianListViewModelTests {

    @MainActor
    private func makeViewModel(
        service: MockComedianService = MockComedianService(),
        pageSize: Int = 20
    ) -> (ComedianListViewModel, MockComedianService) {
        let vm = ComedianListViewModel(comedianService: service, pageSize: pageSize)
        return (vm, service)
    }

    // MARK: - Refresh

    @Test("refresh loads comedians and clears loading state")
    @MainActor
    func refreshLoadsComedians() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1), makeComedian(id: 2)], hasMore: true))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()

        #expect(vm.items.count == 2)
        #expect(vm.hasMorePages == true)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("refresh sets error on failure")
    @MainActor
    func refreshSetsError() async {
        let service = MockComedianService()
        service.searchResult = .failure(TestError.networkFailure)
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()

        #expect(vm.items.isEmpty)
        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("refresh replaces existing items")
    @MainActor
    func refreshReplacesItems() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1)], hasMore: false))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        #expect(vm.items.count == 1)

        await vm.refresh()
        #expect(vm.items.count == 1)
    }

    // MARK: - Load More

    @Test("loadMore appends items and advances page")
    @MainActor
    func loadMoreAppendsItems() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1)], hasMore: true))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        #expect(vm.items.count == 1)

        await vm.loadMore()
        #expect(vm.items.count == 2)
    }

    @Test("loadMore does nothing when no more pages")
    @MainActor
    func loadMoreNoOpWhenExhausted() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1)], hasMore: false))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        let countBefore = vm.items.count

        await vm.loadMore()
        #expect(vm.items.count == countBefore)
    }

    @Test("loadMore sets error on failure")
    @MainActor
    func loadMoreSetsError() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1)], hasMore: true))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        service.searchResult = .failure(TestError.networkFailure)

        await vm.loadMore()
        #expect(vm.error != nil)
        #expect(vm.isLoadingMore == false)
    }

    // MARK: - Search

    @Test("updateSearchText sets search text and refreshes")
    @MainActor
    func updateSearchTextRefreshes() async {
        let service = MockComedianService()
        service.searchResult = .success((comedians: [makeComedian(id: 1)], hasMore: false))
        let (vm, _) = makeViewModel(service: service)

        await vm.updateSearchText("comedy")
        #expect(vm.filters.searchText == "comedy")
    }

    // MARK: - Navigation

    @Test("selectComedian invokes callback")
    @MainActor
    func selectComedianCallback() async {
        let service = MockComedianService()
        let (vm, _) = makeViewModel(service: service)
        let comedian = makeComedian(id: 42)

        var selectedComedian: Comedian?
        vm.onComedianSelected = { selectedComedian = $0 }

        vm.selectComedian(comedian)
        #expect(selectedComedian?.id == 42)
    }

    // MARK: - ComedianSearchFilters

    @Test("isEmpty returns true for default filters")
    func filtersIsEmpty() {
        let filters = ComedianSearchFilters()
        #expect(filters.isEmpty)
    }

    @Test("isEmpty returns false when search text is set")
    func filtersIsNotEmpty() {
        #expect(!ComedianSearchFilters(searchText: "test").isEmpty)
    }
}

// MARK: - Mock FavoritesManager

private final class MockFavoritesManager: FavoritesManagerProtocol, @unchecked Sendable {
    var favoriteStates: [Int: Bool] = [:]
    var setInitialStateCalls: [(comedianId: Int, isFavorite: Bool)] = []
    var toggleFavoriteCalls: [Int] = []
    private let favoriteChangedSubject = PassthroughSubject<Int, Never>()

    var favoriteChanged: AnyPublisher<Int, Never> {
        favoriteChangedSubject.eraseToAnyPublisher()
    }

    func isFavorite(comedianId: Int) -> Bool {
        favoriteStates[comedianId] ?? false
    }

    func setInitialState(comedianId: Int, isFavorite: Bool) {
        setInitialStateCalls.append((comedianId, isFavorite))
        favoriteStates[comedianId] = isFavorite
    }

    @discardableResult
    func toggleFavorite(comedianId: Int) async -> Bool {
        toggleFavoriteCalls.append(comedianId)
        let newValue = !(favoriteStates[comedianId] ?? false)
        favoriteStates[comedianId] = newValue
        favoriteChangedSubject.send(comedianId)
        return newValue
    }

    /// Simulate an external favorite change (e.g., from another screen)
    func simulateFavoriteChanged(comedianId: Int) {
        favoriteChangedSubject.send(comedianId)
    }
}

// MARK: - ComedianDetailViewModel Tests

@Suite("ComedianDetailViewModel")
struct ComedianDetailViewModelTests {

    @MainActor
    private func makeViewModel(
        comedianId: Int = 1,
        service: MockComedianService = MockComedianService()
    ) -> (ComedianDetailViewModel, MockComedianService) {
        let vm = ComedianDetailViewModel(comedianId: comedianId, comedianService: service)
        return (vm, service)
    }

    // MARK: - Load

    @Test("load fetches detail and sets state")
    @MainActor
    func loadFetchesDetail() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 1, isFavorite: true)
        let detail = ComedianDetail(comedian: comedian, upcomingShows: [makeShow()])
        service.detailResult = .success(detail)

        let (vm, _) = makeViewModel(service: service)
        await vm.load()

        #expect(vm.detail != nil)
        #expect(vm.detail?.comedian.name == "Dave Chappelle")
        #expect(vm.isFavorite == true)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("load sets error on failure")
    @MainActor
    func loadSetsError() async {
        let service = MockComedianService()
        service.detailResult = .failure(TestError.networkFailure)

        let (vm, _) = makeViewModel(service: service)
        await vm.load()

        #expect(vm.detail == nil)
        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("load guards against concurrent calls")
    @MainActor
    func loadGuardsConcurrent() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 1)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _) = makeViewModel(service: service)

        // Simulate isLoading already true
        vm.setLoading(true)
        await vm.load()

        // Detail should not have been loaded because guard returned
        #expect(vm.detail == nil)
    }

    // MARK: - Toggle Favorite

    @Test("toggleFavorite optimistically updates and calls service")
    @MainActor
    func toggleFavoriteOptimistic() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 5, isFavorite: false)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _) = makeViewModel(comedianId: 5, service: service)
        await vm.load()
        #expect(vm.isFavorite == false)

        await vm.toggleFavorite()
        #expect(vm.isFavorite == true)
        #expect(service.toggleFavoriteCalls.count == 1)
        #expect(service.toggleFavoriteCalls.first?.comedianId == 5)
        #expect(service.toggleFavoriteCalls.first?.isFavorite == true)
    }

    @Test("toggleFavorite reverts on failure")
    @MainActor
    func toggleFavoriteRevertsOnFailure() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 1, isFavorite: true)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))
        service.toggleFavoriteResult = .failure(TestError.networkFailure)

        let (vm, _) = makeViewModel(service: service)
        await vm.load()
        #expect(vm.isFavorite == true)

        await vm.toggleFavorite()
        #expect(vm.isFavorite == true) // Reverted back
        #expect(vm.error != nil)
    }

    // MARK: - Navigation

    @Test("selectShow invokes callback")
    @MainActor
    func selectShowCallback() async {
        let service = MockComedianService()
        let (vm, _) = makeViewModel(service: service)
        let show = makeShow(id: 99)

        var selectedShow: Show?
        vm.onShowSelected = { selectedShow = $0 }

        vm.selectShow(show)
        #expect(selectedShow?.id == 99)
    }
}

// MARK: - ComedianDetailViewModel + FavoritesManager Integration Tests

@Suite("ComedianDetailViewModel FavoritesManager Integration")
struct ComedianDetailViewModelFavoritesIntegrationTests {

    @MainActor
    private func makeViewModel(
        comedianId: Int = 1,
        service: MockComedianService = MockComedianService(),
        favoritesManager: MockFavoritesManager? = nil
    ) -> (ComedianDetailViewModel, MockComedianService, MockFavoritesManager) {
        let manager = favoritesManager ?? MockFavoritesManager()
        let vm = ComedianDetailViewModel(
            comedianId: comedianId,
            comedianService: service,
            favoritesManager: manager
        )
        return (vm, service, manager)
    }

    // MARK: - toggleFavorite delegation

    @Test("toggleFavorite delegates to FavoritesManager when provided")
    @MainActor
    func toggleFavoriteDelegatesToManager() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 3, isFavorite: false)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, manager) = makeViewModel(comedianId: 3, service: service)
        await vm.load()

        await vm.toggleFavorite()

        #expect(manager.toggleFavoriteCalls == [3])
        // Service should NOT be called directly when manager is present
        #expect(service.toggleFavoriteCalls.isEmpty)
    }

    @Test("toggleFavorite does not call service directly when manager is provided")
    @MainActor
    func toggleFavoriteSkipsDirectService() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 7, isFavorite: true)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, _) = makeViewModel(comedianId: 7, service: service)
        await vm.load()

        await vm.toggleFavorite()
        await vm.toggleFavorite()

        #expect(service.toggleFavoriteCalls.isEmpty)
    }

    // MARK: - favoriteChanged publisher

    @Test("favoriteChanged publisher updates isFavorite on the VM")
    @MainActor
    func favoriteChangedUpdatesVM() async {
        let service = MockComedianService()
        let manager = MockFavoritesManager()
        let comedian = makeComedian(id: 5, isFavorite: false)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, _) = makeViewModel(comedianId: 5, service: service, favoritesManager: manager)
        await vm.load()
        #expect(vm.isFavorite == false)

        // Simulate an external change — manager state flips, then publisher fires
        manager.favoriteStates[5] = true
        manager.simulateFavoriteChanged(comedianId: 5)

        #expect(vm.isFavorite == true)
    }

    @Test("favoriteChanged publisher ignores events for other comedians")
    @MainActor
    func favoriteChangedIgnoresOtherComedians() async {
        let service = MockComedianService()
        let manager = MockFavoritesManager()
        let comedian = makeComedian(id: 2, isFavorite: false)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, _) = makeViewModel(comedianId: 2, service: service, favoritesManager: manager)
        await vm.load()
        #expect(vm.isFavorite == false)

        // Fire change for a different comedian
        manager.favoriteStates[99] = true
        manager.simulateFavoriteChanged(comedianId: 99)

        #expect(vm.isFavorite == false)
    }

    // MARK: - load() calls setInitialState

    @Test("load calls setInitialState on the FavoritesManager")
    @MainActor
    func loadCallsSetInitialState() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 10, isFavorite: true)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, manager) = makeViewModel(comedianId: 10, service: service)
        await vm.load()

        #expect(manager.setInitialStateCalls.count == 1)
        #expect(manager.setInitialStateCalls.first?.comedianId == 10)
        #expect(manager.setInitialStateCalls.first?.isFavorite == true)
    }

    @Test("load passes isFavorite=false to setInitialState when comedian is not favorited")
    @MainActor
    func loadPassesFalseToSetInitialState() async {
        let service = MockComedianService()
        let comedian = makeComedian(id: 4, isFavorite: false)
        service.detailResult = .success(ComedianDetail(comedian: comedian, upcomingShows: []))

        let (vm, _, manager) = makeViewModel(comedianId: 4, service: service)
        await vm.load()

        #expect(manager.setInitialStateCalls.count == 1)
        #expect(manager.setInitialStateCalls.first?.isFavorite == false)
    }
}

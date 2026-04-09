import Foundation
@testable import SharedKit
import Testing

// MARK: - Mock Service

private final class MockClubService: ClubServiceProtocol, @unchecked Sendable {
    var searchResult: Result<(clubs: [Club], hasMore: Bool), Error> = .success((clubs: [], hasMore: false))
    var detailResult: Result<ClubDetail, Error> = .failure(TestError.notImplemented)

    func searchClubs(filters: ClubSearchFilters, page: Int, pageSize: Int) async throws -> (clubs: [Club], hasMore: Bool) {
        try searchResult.get()
    }

    func getClub(id: Int) async throws -> ClubDetail {
        try detailResult.get()
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

private func makeClub(id: Int = 1, name: String = "The Comedy Store") -> Club {
    Club(
        id: id,
        name: name,
        address: "8433 Sunset Blvd, Los Angeles, CA",
        phoneNumber: "(323) 650-6268",
        websiteURL: URL(string: "https://thecomedystore.com"),
        imageURL: URL(string: "https://example.com/img/\(id).jpg")
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

// MARK: - ClubListViewModel Tests

@Suite("ClubListViewModel")
struct ClubListViewModelTests {

    @MainActor
    private func makeViewModel(
        service: MockClubService = MockClubService(),
        pageSize: Int = 20
    ) -> (ClubListViewModel, MockClubService) {
        let vm = ClubListViewModel(clubService: service, pageSize: pageSize)
        return (vm, service)
    }

    // MARK: - Refresh

    @Test("refresh loads clubs and clears loading state")
    @MainActor
    func refreshLoadsClubs() async {
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1), makeClub(id: 2)], hasMore: true))
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
        let service = MockClubService()
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
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1)], hasMore: false))
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
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1)], hasMore: true))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        #expect(vm.items.count == 1)

        await vm.loadMore()
        #expect(vm.items.count == 2)
    }

    @Test("loadMore does nothing when no more pages")
    @MainActor
    func loadMoreNoOpWhenExhausted() async {
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1)], hasMore: false))
        let (vm, _) = makeViewModel(service: service)

        await vm.refresh()
        let countBefore = vm.items.count

        await vm.loadMore()
        #expect(vm.items.count == countBefore)
    }

    @Test("loadMore sets error on failure")
    @MainActor
    func loadMoreSetsError() async {
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1)], hasMore: true))
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
        let service = MockClubService()
        service.searchResult = .success((clubs: [makeClub(id: 1)], hasMore: false))
        let (vm, _) = makeViewModel(service: service)

        await vm.updateSearchText("comedy")
        #expect(vm.filters.searchText == "comedy")
    }

    // MARK: - Navigation

    @Test("selectClub invokes callback")
    @MainActor
    func selectClubCallback() async {
        let service = MockClubService()
        let (vm, _) = makeViewModel(service: service)
        let club = makeClub(id: 42)

        var selectedClub: Club?
        vm.onClubSelected = { selectedClub = $0 }

        vm.selectClub(club)
        #expect(selectedClub?.id == 42)
    }

    // MARK: - ClubSearchFilters

    @Test("isEmpty returns true for default filters")
    func filtersIsEmpty() {
        let filters = ClubSearchFilters()
        #expect(filters.isEmpty)
    }

    @Test("isEmpty returns false when search text is set")
    func filtersIsNotEmpty() {
        #expect(!ClubSearchFilters(searchText: "test").isEmpty)
    }
}

// MARK: - ClubDetailViewModel Tests

@Suite("ClubDetailViewModel")
struct ClubDetailViewModelTests {

    @MainActor
    private func makeViewModel(
        clubId: Int = 1,
        service: MockClubService = MockClubService()
    ) -> (ClubDetailViewModel, MockClubService) {
        let vm = ClubDetailViewModel(clubId: clubId, clubService: service)
        return (vm, service)
    }

    // MARK: - Load

    @Test("load fetches detail and sets state")
    @MainActor
    func loadFetchesDetail() async {
        let service = MockClubService()
        let club = makeClub(id: 1)
        let detail = ClubDetail(club: club, upcomingShows: [makeShow()])
        service.detailResult = .success(detail)

        let (vm, _) = makeViewModel(service: service)
        await vm.load()

        #expect(vm.detail != nil)
        #expect(vm.detail?.club.name == "The Comedy Store")
        #expect(vm.detail?.upcomingShows.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("load sets error on failure")
    @MainActor
    func loadSetsError() async {
        let service = MockClubService()
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
        let service = MockClubService()
        let club = makeClub(id: 1)
        service.detailResult = .success(ClubDetail(club: club, upcomingShows: []))

        let (vm, _) = makeViewModel(service: service)

        // Simulate isLoading already true
        vm.setLoading(true)
        await vm.load()

        // Detail should not have been loaded because guard returned
        #expect(vm.detail == nil)
    }

    // MARK: - Navigation

    @Test("selectShow invokes callback")
    @MainActor
    func selectShowCallback() async {
        let service = MockClubService()
        let (vm, _) = makeViewModel(service: service)
        let show = makeShow(id: 99)

        var selectedShow: Show?
        vm.onShowSelected = { selectedShow = $0 }

        vm.selectShow(show)
        #expect(selectedShow?.id == 99)
    }
}

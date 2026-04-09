import Foundation
@testable import SharedKit
import Testing

// MARK: - Mock Service

private struct MockShowService: ShowServiceProtocol {
    var result: Result<(shows: [Show], hasMore: Bool), Error> = .success((shows: [], hasMore: false))

    func searchShows(filters: ShowSearchFilters, page: Int, pageSize: Int) async throws -> (shows: [Show], hasMore: Bool) {
        try result.get()
    }
}

private enum TestError: Error, LocalizedError {
    case networkFailure
    var errorDescription: String? { "Network failure" }
}

private func makeShow(id: Int = 1) -> Show {
    Show(
        id: id,
        comedians: ["Dave Chappelle", "Ali Wong"],
        venueName: "The Comedy Store",
        date: Date(),
        ticketURL: URL(string: "https://example.com/tickets")
    )
}

@Suite("ShowListViewModel")
struct ShowListViewModelTests {

    @MainActor
    private func makeViewModel(
        result: Result<(shows: [Show], hasMore: Bool), Error> = .success((shows: [], hasMore: false)),
        pageSize: Int = 20
    ) -> ShowListViewModel {
        let service = MockShowService(result: result)
        return ShowListViewModel(showService: service, pageSize: pageSize)
    }

    // MARK: - Refresh

    @Test("refresh loads shows and clears loading state")
    @MainActor
    func refreshLoadsShows() async {
        let shows = [makeShow(id: 1), makeShow(id: 2)]
        let vm = makeViewModel(result: .success((shows: shows, hasMore: true)))

        await vm.refresh()

        #expect(vm.items.count == 2)
        #expect(vm.hasMorePages == true)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("refresh sets error on failure")
    @MainActor
    func refreshSetsError() async {
        let vm = makeViewModel(result: .failure(TestError.networkFailure))

        await vm.refresh()

        #expect(vm.items.isEmpty)
        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("refresh replaces existing items")
    @MainActor
    func refreshReplacesItems() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: false)))
        await vm.refresh()
        #expect(vm.items.count == 1)

        // Refresh again with different data — items replaced
        await vm.refresh()
        #expect(vm.items.count == 1)
    }

    // MARK: - Load More

    @Test("loadMore appends items and advances page")
    @MainActor
    func loadMoreAppendsItems() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: true)))

        await vm.refresh()
        #expect(vm.items.count == 1)

        await vm.loadMore()
        #expect(vm.items.count == 2)
    }

    @Test("loadMore does nothing when no more pages")
    @MainActor
    func loadMoreNoOpWhenExhausted() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: false)))

        await vm.refresh()
        let countBefore = vm.items.count

        await vm.loadMore()
        #expect(vm.items.count == countBefore)
    }

    // MARK: - Filters

    @Test("applyFilters updates filters and refreshes")
    @MainActor
    func applyFiltersRefreshes() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: false)))

        let filters = ShowSearchFilters(comedian: "Ali Wong")
        await vm.applyFilters(filters)

        #expect(vm.filters.comedian == "Ali Wong")
        #expect(vm.items.count == 1)
    }

    @Test("clearFilters resets filters and refreshes")
    @MainActor
    func clearFiltersResets() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: false)))

        await vm.applyFilters(ShowSearchFilters(comedian: "Test"))
        #expect(vm.filters.comedian == "Test")

        await vm.clearFilters()
        #expect(vm.filters.isEmpty)
    }

    @Test("updateSearchText sets search text and refreshes")
    @MainActor
    func updateSearchTextRefreshes() async {
        let vm = makeViewModel(result: .success((shows: [makeShow(id: 1)], hasMore: false)))

        await vm.updateSearchText("comedy")
        #expect(vm.filters.searchText == "comedy")
    }

    // MARK: - Navigation

    @Test("selectShow invokes callback")
    @MainActor
    func selectShowCallback() async {
        let vm = makeViewModel()
        let show = makeShow(id: 42)

        var selectedShow: Show?
        vm.onShowSelected = { selectedShow = $0 }

        vm.selectShow(show)
        #expect(selectedShow?.id == 42)
    }

    // MARK: - ShowSearchFilters

    @Test("isEmpty returns true for default filters")
    func filtersIsEmpty() {
        let filters = ShowSearchFilters()
        #expect(filters.isEmpty)
    }

    @Test("isEmpty returns false when any filter is set")
    func filtersIsNotEmpty() {
        #expect(!ShowSearchFilters(searchText: "test").isEmpty)
        #expect(!ShowSearchFilters(comedian: "Ali").isEmpty)
        #expect(!ShowSearchFilters(club: "Store").isEmpty)
        #expect(!ShowSearchFilters(startDate: Date()).isEmpty)
    }
}

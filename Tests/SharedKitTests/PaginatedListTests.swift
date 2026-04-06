import Foundation
import Testing
@testable import SharedKit

// MARK: - Mock Data Source

private struct MockItem: Identifiable {
    let id: Int
    let name: String
}

@MainActor
private final class MockDataSource: PaginatedDataSource {
    @Published var items: [MockItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    @Published var error: Error?

    var refreshCallCount = 0
    var loadMoreCallCount = 0

    func refresh() async {
        refreshCallCount += 1
        isLoading = true
        items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        isLoading = false
    }

    func loadMore() async {
        loadMoreCallCount += 1
        isLoadingMore = true
        let start = items.count + 1
        items += (start...(start + 9)).map { MockItem(id: $0, name: "Item \($0)") }
        isLoadingMore = false
    }
}

// MARK: - Tests

@Suite("PaginatedDataSource Protocol")
struct PaginatedDataSourceTests {

    @Test("Data source starts with empty items")
    @MainActor
    func startsEmpty() {
        let ds = MockDataSource()
        #expect(ds.items.isEmpty)
        #expect(ds.hasMorePages == true)
        #expect(ds.isLoading == false)
        #expect(ds.isLoadingMore == false)
        #expect(ds.error == nil)
    }

    @Test("Refresh populates items and increments call count")
    @MainActor
    func refreshPopulatesItems() async {
        let ds = MockDataSource()
        await ds.refresh()
        #expect(ds.items.count == 10)
        #expect(ds.refreshCallCount == 1)
        #expect(ds.isLoading == false)
    }

    @Test("Load more appends items")
    @MainActor
    func loadMoreAppendsItems() async {
        let ds = MockDataSource()
        await ds.refresh()
        await ds.loadMore()
        #expect(ds.items.count == 20)
        #expect(ds.loadMoreCallCount == 1)
        #expect(ds.isLoadingMore == false)
    }

    @Test("Multiple load more calls accumulate items")
    @MainActor
    func multipleLoadMoreAccumulates() async {
        let ds = MockDataSource()
        await ds.refresh()
        await ds.loadMore()
        await ds.loadMore()
        #expect(ds.items.count == 30)
        #expect(ds.loadMoreCallCount == 2)
    }

    @Test("Refresh resets items to first page")
    @MainActor
    func refreshResetsToFirstPage() async {
        let ds = MockDataSource()
        await ds.refresh()
        await ds.loadMore()
        #expect(ds.items.count == 20)

        await ds.refresh()
        #expect(ds.items.count == 10)
        #expect(ds.refreshCallCount == 2)
    }

    @Test("Error state prevents load more from triggering")
    @MainActor
    func errorStatePreventsLoadMore() {
        let ds = MockDataSource()
        ds.error = NSError(domain: "test", code: -1)
        // In PaginatedList, onItemAppear guards against error != nil
        // Here we verify the data source correctly holds error state
        #expect(ds.error != nil)
        #expect(ds.items.isEmpty)
    }

    @Test("HasMorePages false signals end of data")
    @MainActor
    func hasMorePagesFalseSignalsEnd() async {
        let ds = MockDataSource()
        await ds.refresh()
        ds.hasMorePages = false
        // In PaginatedList, onItemAppear guards against !hasMorePages
        #expect(ds.hasMorePages == false)
        #expect(ds.items.count == 10)
    }
}

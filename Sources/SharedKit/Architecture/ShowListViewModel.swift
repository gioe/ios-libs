import Foundation

// MARK: - ViewModel

/// ViewModel for the show search and listing screen.
///
/// Manages paginated show loading with filter support for date range, comedian, and club.
/// Conforms to `PaginatedDataSource` for use with `PaginatedList`.
@MainActor
public class ShowListViewModel: BaseViewModel, PaginatedDataSource {
    // MARK: - Published State

    @Published public var items: [Show] = []
    @Published public var isLoadingMore: Bool = false
    @Published public var hasMorePages: Bool = true
    @Published public var filters: ShowSearchFilters = ShowSearchFilters()

    // MARK: - Dependencies

    private let showService: any ShowServiceProtocol
    private let pageSize: Int

    // MARK: - Internal State

    private var currentPage: Int = 0

    // MARK: - Navigation

    /// Callback invoked when the user taps a show card.
    /// Consumer apps use this to navigate to comedian or club detail.
    public var onShowSelected: ((Show) -> Void)?

    // MARK: - Initialization

    public init(
        showService: any ShowServiceProtocol,
        pageSize: Int = 20,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.showService = showService
        self.pageSize = pageSize
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - PaginatedDataSource

    public func refresh() async {
        clearError()
        setLoading(true)
        currentPage = 0

        do {
            let result = try await showService.searchShows(filters: filters, page: 0, pageSize: pageSize)
            items = result.shows
            hasMorePages = result.hasMore
            setLoading(false)
        } catch {
            handleError(error, context: "searchShows") { [weak self] in
                await self?.refresh()
            }
        }
    }

    public func loadMore() async {
        guard hasMorePages, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let result = try await showService.searchShows(filters: filters, page: nextPage, pageSize: pageSize)
            items += result.shows
            hasMorePages = result.hasMore
            currentPage = nextPage
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            handleError(error, context: "loadMoreShows") { [weak self] in
                await self?.loadMore()
            }
        }
    }

    // MARK: - Filter Actions

    /// Apply updated filters and refresh the list.
    public func applyFilters(_ newFilters: ShowSearchFilters) async {
        filters = newFilters
        await refresh()
    }

    /// Clear all filters and refresh.
    public func clearFilters() async {
        filters = ShowSearchFilters()
        await refresh()
    }

    /// Update the search text (called from debounced search bar).
    public func updateSearchText(_ text: String) async {
        filters.searchText = text
        await refresh()
    }

    // MARK: - Navigation

    public func selectShow(_ show: Show) {
        onShowSelected?(show)
    }
}

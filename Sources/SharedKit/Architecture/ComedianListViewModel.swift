import Foundation

// MARK: - ViewModel

/// ViewModel for the comedian search and listing screen.
///
/// Manages paginated comedian loading with search support.
/// Conforms to `PaginatedDataSource` for use with `PaginatedList`.
@MainActor
public class ComedianListViewModel: BaseViewModel, PaginatedDataSource {
    // MARK: - Published State

    @Published public var items: [Comedian] = []
    @Published public var isLoadingMore: Bool = false
    @Published public var hasMorePages: Bool = true
    @Published public var filters: ComedianSearchFilters = ComedianSearchFilters()

    // MARK: - Dependencies

    private let comedianService: any ComedianServiceProtocol
    private let pageSize: Int

    // MARK: - Internal State

    private var currentPage: Int = 0

    // MARK: - Navigation

    /// Callback invoked when the user taps a comedian card.
    public var onComedianSelected: ((Comedian) -> Void)?

    // MARK: - Initialization

    public init(
        comedianService: any ComedianServiceProtocol,
        pageSize: Int = 20,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.comedianService = comedianService
        self.pageSize = pageSize
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - PaginatedDataSource

    public func refresh() async {
        clearError()
        setLoading(true)
        currentPage = 0

        do {
            let result = try await comedianService.searchComedians(filters: filters, page: 0, pageSize: pageSize)
            items = result.comedians
            hasMorePages = result.hasMore
            setLoading(false)
        } catch {
            handleError(error, context: "searchComedians") { [weak self] in
                await self?.refresh()
            }
        }
    }

    public func loadMore() async {
        guard hasMorePages, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let result = try await comedianService.searchComedians(filters: filters, page: nextPage, pageSize: pageSize)
            items += result.comedians
            hasMorePages = result.hasMore
            currentPage = nextPage
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            handleError(error, context: "loadMoreComedians") { [weak self] in
                await self?.loadMore()
            }
        }
    }

    // MARK: - Search

    /// Update the search text (called from debounced search bar).
    public func updateSearchText(_ text: String) async {
        filters.searchText = text
        await refresh()
    }

    // MARK: - Navigation

    public func selectComedian(_ comedian: Comedian) {
        onComedianSelected?(comedian)
    }
}

import Foundation

// MARK: - Models

/// A comedy show for display in the show listing screen.
///
/// Consumer apps map their API response types to this struct.
public struct Show: Identifiable, Sendable, Equatable {
    public let id: Int
    public let comedians: [String]
    public let venueName: String
    public let date: Date
    public let ticketURL: URL?

    public init(id: Int, comedians: [String], venueName: String, date: Date, ticketURL: URL?) {
        self.id = id
        self.comedians = comedians
        self.venueName = venueName
        self.date = date
        self.ticketURL = ticketURL
    }
}

/// Filter parameters for show search.
public struct ShowSearchFilters: Equatable, Sendable {
    public var searchText: String
    public var startDate: Date?
    public var endDate: Date?
    public var comedian: String?
    public var club: String?

    public init(
        searchText: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        comedian: String? = nil,
        club: String? = nil
    ) {
        self.searchText = searchText
        self.startDate = startDate
        self.endDate = endDate
        self.comedian = comedian
        self.club = club
    }

    public var isEmpty: Bool {
        searchText.isEmpty && startDate == nil && endDate == nil && comedian == nil && club == nil
    }
}

// MARK: - Service Protocol

/// Protocol defining the data contract for the show listing screen.
///
/// Consumer apps implement this to connect the show list to their backend.
public protocol ShowServiceProtocol: Sendable {
    /// Fetches a page of shows matching the given filters.
    /// - Parameters:
    ///   - filters: The active search/filter criteria.
    ///   - page: Zero-based page index.
    ///   - pageSize: Number of items per page.
    /// - Returns: A tuple of the shows and whether more pages are available.
    func searchShows(filters: ShowSearchFilters, page: Int, pageSize: Int) async throws -> (shows: [Show], hasMore: Bool)
}

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

import Foundation

// MARK: - Models

/// A comedy club for display in the club listing screen.
///
/// Consumer apps map their API response types to this struct.
public struct Club: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let address: String
    public let phoneNumber: String?
    public let websiteURL: URL?
    public let imageURL: URL?

    public init(
        id: Int,
        name: String,
        address: String,
        phoneNumber: String? = nil,
        websiteURL: URL? = nil,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.imageURL = imageURL
    }
}

/// Full club detail including upcoming shows.
public struct ClubDetail: Sendable, Equatable {
    public let club: Club
    public let upcomingShows: [Show]

    public init(club: Club, upcomingShows: [Show]) {
        self.club = club
        self.upcomingShows = upcomingShows
    }
}

/// Filter parameters for club search.
public struct ClubSearchFilters: Equatable, Sendable {
    public var searchText: String

    public init(searchText: String = "") {
        self.searchText = searchText
    }

    public var isEmpty: Bool {
        searchText.isEmpty
    }
}

// MARK: - Service Protocol

/// Protocol defining the data contract for the club listing screen.
///
/// Consumer apps implement this to connect the club list to their backend.
public protocol ClubServiceProtocol: Sendable {
    /// Fetches a page of clubs matching the given filters.
    func searchClubs(filters: ClubSearchFilters, page: Int, pageSize: Int) async throws -> (clubs: [Club], hasMore: Bool)

    /// Fetches a single club's full details.
    func getClub(id: Int) async throws -> ClubDetail
}

// MARK: - List ViewModel

/// ViewModel for the club search and listing screen.
///
/// Manages paginated club loading with search support.
/// Conforms to `PaginatedDataSource` for use with `PaginatedList`.
@MainActor
public class ClubListViewModel: BaseViewModel, PaginatedDataSource {
    // MARK: - Published State

    @Published public var items: [Club] = []
    @Published public var isLoadingMore: Bool = false
    @Published public var hasMorePages: Bool = true
    @Published public var filters: ClubSearchFilters = ClubSearchFilters()

    // MARK: - Dependencies

    private let clubService: any ClubServiceProtocol
    private let pageSize: Int

    // MARK: - Internal State

    private var currentPage: Int = 0

    // MARK: - Navigation

    /// Callback invoked when the user taps a club card.
    public var onClubSelected: ((Club) -> Void)?

    // MARK: - Initialization

    public init(
        clubService: any ClubServiceProtocol,
        pageSize: Int = 20,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.clubService = clubService
        self.pageSize = pageSize
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - PaginatedDataSource

    public func refresh() async {
        clearError()
        setLoading(true)
        currentPage = 0

        do {
            let result = try await clubService.searchClubs(filters: filters, page: 0, pageSize: pageSize)
            items = result.clubs
            hasMorePages = result.hasMore
            setLoading(false)
        } catch {
            handleError(error, context: "searchClubs") { [weak self] in
                await self?.refresh()
            }
        }
    }

    public func loadMore() async {
        guard hasMorePages, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let result = try await clubService.searchClubs(filters: filters, page: nextPage, pageSize: pageSize)
            items += result.clubs
            hasMorePages = result.hasMore
            currentPage = nextPage
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            handleError(error, context: "loadMoreClubs") { [weak self] in
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

    public func selectClub(_ club: Club) {
        onClubSelected?(club)
    }
}

// MARK: - Detail ViewModel

/// ViewModel for the club detail screen.
///
/// Loads a single club's full details including upcoming shows.
@MainActor
public class ClubDetailViewModel: BaseViewModel {
    // MARK: - Published State

    @Published public var detail: ClubDetail?

    // MARK: - Dependencies

    private let clubService: any ClubServiceProtocol
    private let clubId: Int

    // MARK: - Navigation

    /// Callback invoked when the user taps a show in the upcoming shows list.
    public var onShowSelected: ((Show) -> Void)?

    // MARK: - Initialization

    public init(
        clubId: Int,
        clubService: any ClubServiceProtocol,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.clubId = clubId
        self.clubService = clubService
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - Loading

    /// Loads the club detail from the service.
    public func load() async {
        guard !isLoading else { return }
        clearError()
        setLoading(true)

        do {
            let result = try await clubService.getClub(id: clubId)
            detail = result
            setLoading(false)
        } catch {
            handleError(error, context: "getClub") { [weak self] in
                await self?.load()
            }
        }
    }

    // MARK: - Navigation

    /// Called when the user taps a show in the upcoming shows list.
    public func selectShow(_ show: Show) {
        onShowSelected?(show)
    }
}

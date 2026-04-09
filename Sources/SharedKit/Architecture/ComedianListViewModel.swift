import Foundation

// MARK: - Models

/// A comedian for display in the comedian listing screen.
///
/// Consumer apps map their API response types to this struct.
public struct Comedian: Identifiable, Sendable, Equatable {
    public let id: Int
    public let uuid: String
    public let name: String
    public let imageURL: URL?
    public let showCount: Int
    public let isFavorite: Bool
    public let socialLinks: ComedianSocialLinks

    public init(
        id: Int,
        uuid: String,
        name: String,
        imageURL: URL?,
        showCount: Int,
        isFavorite: Bool = false,
        socialLinks: ComedianSocialLinks = ComedianSocialLinks()
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.imageURL = imageURL
        self.showCount = showCount
        self.isFavorite = isFavorite
        self.socialLinks = socialLinks
    }
}

/// Social media links and follower counts for a comedian.
public struct ComedianSocialLinks: Sendable, Equatable {
    public let instagramAccount: String?
    public let instagramFollowers: Int?
    public let tiktokAccount: String?
    public let tiktokFollowers: Int?
    public let youtubeAccount: String?
    public let youtubeFollowers: Int?
    public let website: String?
    public let linktree: String?

    public init(
        instagramAccount: String? = nil,
        instagramFollowers: Int? = nil,
        tiktokAccount: String? = nil,
        tiktokFollowers: Int? = nil,
        youtubeAccount: String? = nil,
        youtubeFollowers: Int? = nil,
        website: String? = nil,
        linktree: String? = nil
    ) {
        self.instagramAccount = instagramAccount
        self.instagramFollowers = instagramFollowers
        self.tiktokAccount = tiktokAccount
        self.tiktokFollowers = tiktokFollowers
        self.youtubeAccount = youtubeAccount
        self.youtubeFollowers = youtubeFollowers
        self.website = website
        self.linktree = linktree
    }
}

/// Filter parameters for comedian search.
public struct ComedianSearchFilters: Equatable, Sendable {
    public var searchText: String

    public init(searchText: String = "") {
        self.searchText = searchText
    }

    public var isEmpty: Bool {
        searchText.isEmpty
    }
}

// MARK: - Service Protocol

/// Protocol defining the data contract for the comedian listing screen.
///
/// Consumer apps implement this to connect the comedian list to their backend.
public protocol ComedianServiceProtocol: Sendable {
    /// Fetches a page of comedians matching the given filters.
    func searchComedians(filters: ComedianSearchFilters, page: Int, pageSize: Int) async throws -> (comedians: [Comedian], hasMore: Bool)

    /// Fetches a single comedian's full details.
    func getComedian(id: Int) async throws -> ComedianDetail

    /// Toggles the favorite status for a comedian.
    func toggleFavorite(comedianId: Int, isFavorite: Bool) async throws
}

// MARK: - Detail Model

/// Full comedian detail including show history.
public struct ComedianDetail: Sendable, Equatable {
    public let comedian: Comedian
    public let upcomingShows: [Show]

    public init(comedian: Comedian, upcomingShows: [Show]) {
        self.comedian = comedian
        self.upcomingShows = upcomingShows
    }
}

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

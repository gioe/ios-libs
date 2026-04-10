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

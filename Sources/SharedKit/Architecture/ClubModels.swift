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

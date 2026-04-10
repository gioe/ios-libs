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

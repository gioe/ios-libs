import Foundation

/// An analytics event with a name and optional parameters
public struct AnalyticsEvent {
    public let name: String
    public let parameters: [String: Any]?

    public init(name: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.parameters = parameters
    }
}

/// Protocol for analytics providers (Firebase, Mixpanel, etc.)
///
/// Consumers implement this protocol with their chosen analytics backend
/// and register instances with `AnalyticsManager`. Complements `ErrorRecorder`
/// which handles crash/error reporting — this protocol covers event tracking,
/// screen tracking, and user properties.
public protocol AnalyticsProvider {
    /// Track a discrete event (e.g., button tap, purchase completed)
    func track(_ event: AnalyticsEvent)

    /// Track a screen view
    func trackScreen(_ name: String, parameters: [String: Any]?)

    /// Set a user property that persists across events
    func setUserProperty(_ value: String?, forName name: String)

    /// Set the user identifier for all subsequent events
    func setUserID(_ userID: String?)

    /// Reset all user data (e.g., on logout)
    func reset()
}

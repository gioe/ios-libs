import Foundation
import os

/// Protocol for the analytics manager, enabling DI and mocking
public protocol AnalyticsManagerProtocol {
    /// Register an analytics provider
    func addProvider(_ provider: AnalyticsProvider)

    /// Track a discrete event
    func track(_ event: AnalyticsEvent)

    /// Track a discrete event by name with optional parameters
    func track(_ name: String, parameters: [String: Any]?)

    /// Track a screen view
    func trackScreen(_ name: String, parameters: [String: Any]?)

    /// Set a user property
    func setUserProperty(_ value: String?, forName name: String)

    /// Set the user identifier
    func setUserID(_ userID: String?)

    /// Reset all providers (e.g., on logout)
    func reset()
}

/// Dispatches analytics calls to all registered providers
///
/// Register concrete providers at app startup:
/// ```swift
/// let analytics = AnalyticsManager()
/// analytics.addProvider(FirebaseAnalyticsProvider())
/// analytics.addProvider(MixpanelProvider())
/// container.register(AnalyticsManagerProtocol.self, scope: .appLevel) { analytics }
/// ```
///
/// With no providers registered, all calls are no-ops — safe for previews and tests.
public final class AnalyticsManager: AnalyticsManagerProtocol {
    private let logger: Logger
    private var providers: [AnalyticsProvider] = []

    public init(subsystem: String = "com.sharedkit") {
        logger = Logger(subsystem: subsystem, category: "AnalyticsManager")
    }

    public func addProvider(_ provider: AnalyticsProvider) {
        providers.append(provider)
        logger.debug("Added analytics provider: \(String(describing: type(of: provider)), privacy: .public)")
    }

    public func track(_ event: AnalyticsEvent) {
        logger.debug("Track event: \(event.name, privacy: .public)")
        for provider in providers {
            provider.track(event)
        }
    }

    public func track(_ name: String, parameters: [String: Any]? = nil) {
        track(AnalyticsEvent(name: name, parameters: parameters))
    }

    public func trackScreen(_ name: String, parameters: [String: Any]? = nil) {
        logger.debug("Track screen: \(name, privacy: .public)")
        for provider in providers {
            provider.trackScreen(name, parameters: parameters)
        }
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        logger.debug("Set user property: \(name, privacy: .public)")
        for provider in providers {
            provider.setUserProperty(value, forName: name)
        }
    }

    public func setUserID(_ userID: String?) {
        logger.debug("Set user ID")
        for provider in providers {
            provider.setUserID(userID)
        }
    }

    public func reset() {
        logger.debug("Reset all analytics providers")
        for provider in providers {
            provider.reset()
        }
    }
}

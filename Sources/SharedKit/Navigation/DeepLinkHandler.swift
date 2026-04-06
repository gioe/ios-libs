import Foundation
import os
import SwiftUI

/// The navigation action to perform when a deep link is resolved.
public enum DeepLinkAction<Route: Hashable> {
    /// Push the route onto the navigation stack.
    case push(Route)

    /// Present the route modally with the given style.
    case present(Route, style: PresentationStyle)

    /// Pop to root, then push the route.
    case popToRootThenPush(Route)
}

/// A parser that maps URLs to navigation actions.
///
/// Consumers implement this protocol to define their app's URL scheme
/// and universal link handling. Return `nil` for unrecognized URLs.
///
/// ```swift
/// struct AppDeepLinkParser: DeepLinkParser {
///     func parse(url: URL) -> DeepLinkAction<AppRoute>? {
///         guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
///             return nil
///         }
///         switch components.path {
///         case "/profile":
///             return .push(.profile)
///         case "/settings":
///             return .present(.settings, style: .sheet)
///         default:
///             return nil
///         }
///     }
/// }
/// ```
public protocol DeepLinkParser<Route> {
    associatedtype Route: Hashable

    /// Parse a URL into a navigation action, or `nil` if the URL is unrecognized.
    func parse(url: URL) -> DeepLinkAction<Route>?
}

/// Routes deep links through a ``NavigationCoordinator``.
///
/// `DeepLinkHandler` connects a consumer-provided ``DeepLinkParser`` to a
/// ``NavigationCoordinator``, translating incoming URLs into navigation
/// actions (push, present, or pop-to-root-then-push).
///
/// Usage:
/// ```swift
/// let coordinator = NavigationCoordinator<AppRoute>()
/// let handler = DeepLinkHandler(coordinator: coordinator, parser: AppDeepLinkParser())
///
/// // In SwiftUI:
/// ContentView()
///     .onDeepLink(handler: handler)
/// ```
@MainActor
public class DeepLinkHandler<Parser: DeepLinkParser> {
    public typealias Route = Parser.Route

    private let coordinator: NavigationCoordinator<Route>
    private let parser: Parser
    private let logger: Logger

    public init(
        coordinator: NavigationCoordinator<Route>,
        parser: Parser,
        loggerSubsystem: String = "com.sharedkit"
    ) {
        self.coordinator = coordinator
        self.parser = parser
        self.logger = Logger(subsystem: loggerSubsystem, category: "DeepLinkHandler")
    }

    /// Handle an incoming URL by parsing it and routing through the coordinator.
    ///
    /// - Parameter url: The URL to handle (custom scheme or universal link).
    /// - Returns: `true` if the URL was recognized and routed, `false` otherwise.
    @discardableResult
    public func handle(url: URL) -> Bool {
        logger.debug("Handling URL: \(url.absoluteString, privacy: .public)")

        guard let action = parser.parse(url: url) else {
            logger.debug("Unrecognized URL: \(url.absoluteString, privacy: .public)")
            return false
        }

        switch action {
        case .push(let route):
            coordinator.push(route)
        case .present(let route, let style):
            coordinator.present(route, style: style)
        case .popToRootThenPush(let route):
            coordinator.popToRoot()
            coordinator.push(route)
        }

        return true
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Registers a ``DeepLinkHandler`` to receive URLs opened with this app.
    ///
    /// This is a convenience wrapper around SwiftUI's `onOpenURL` that
    /// forwards incoming URLs to the handler.
    public func onDeepLink<Parser: DeepLinkParser>(
        handler: DeepLinkHandler<Parser>
    ) -> some View {
        onOpenURL { url in
            handler.handle(url: url)
        }
    }
}

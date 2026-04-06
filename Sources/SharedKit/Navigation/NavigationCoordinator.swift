import Foundation
import os
import SwiftUI

/// Style for presenting a view modally.
public enum PresentationStyle: Sendable {
    case sheet
    case fullScreenCover
}

/// A modal presentation request wrapping an arbitrary route.
public struct ModalPresentation<Route: Hashable>: Identifiable {
    public let id = UUID()
    public let route: Route
    public let style: PresentationStyle

    public init(route: Route, style: PresentationStyle) {
        self.route = route
        self.style = style
    }
}

/// Protocol for navigation coordination.
///
/// Consumers define a `Route` enum conforming to `Hashable` and use the
/// coordinator to push, pop, and present routes in a type-safe way.
@MainActor
public protocol NavigationCoordinatorProtocol<Route>: ObservableObject {
    associatedtype Route: Hashable

    /// The navigation path driving `NavigationStack`.
    var path: NavigationPath { get set }

    /// The currently presented modal, if any.
    var activeModal: ModalPresentation<Route>? { get set }

    /// Push a route onto the navigation stack.
    func push(_ route: Route)

    /// Pop the top route from the navigation stack.
    func pop()

    /// Pop to the root of the navigation stack.
    func popToRoot()

    /// Present a route modally as a sheet or full-screen cover.
    func present(_ route: Route, style: PresentationStyle)

    /// Dismiss the currently presented modal.
    func dismissModal()
}

/// A generic, reusable navigation coordinator for SwiftUI.
///
/// `NavigationCoordinator` manages both stack-based (push/pop) and modal
/// (sheet/full-screen cover) navigation with type-safe route definitions.
/// It integrates with `NavigationStack` via its published `path` property
/// and is composable across feature modules — each feature can own its
/// own coordinator instance with its own `Route` type.
///
/// Usage:
/// ```swift
/// enum AppRoute: Hashable {
///     case detail(id: String)
///     case settings
///     case profile
/// }
///
/// let coordinator = NavigationCoordinator<AppRoute>()
/// coordinator.push(.detail(id: "123"))
/// coordinator.present(.settings, style: .sheet)
/// ```
@MainActor
public class NavigationCoordinator<Route: Hashable>: ObservableObject, NavigationCoordinatorProtocol {
    @Published public var path = NavigationPath()
    @Published public var activeModal: ModalPresentation<Route>?

    private let logger: Logger

    public init(loggerSubsystem: String = "com.sharedkit") {
        logger = Logger(subsystem: loggerSubsystem, category: "NavigationCoordinator")
    }

    public func push(_ route: Route) {
        logger.debug("Push: \(String(describing: route), privacy: .public)")
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else {
            logger.debug("Pop ignored — path is empty")
            return
        }
        logger.debug("Pop")
        path.removeLast()
    }

    public func popToRoot() {
        guard !path.isEmpty else { return }
        logger.debug("Pop to root (depth: \(self.path.count))")
        path = NavigationPath()
    }

    public func present(_ route: Route, style: PresentationStyle) {
        logger.debug("Present \(String(describing: style)): \(String(describing: route), privacy: .public)")
        activeModal = ModalPresentation(route: route, style: style)
    }

    public func dismissModal() {
        guard activeModal != nil else { return }
        logger.debug("Dismiss modal")
        activeModal = nil
    }
}

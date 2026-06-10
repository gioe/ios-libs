import Foundation
import os
import SwiftUI

/// A navigation coordinator whose stack is a typed `[Route]` array instead of
/// an opaque `NavigationPath`.
///
/// `NavigationPath` erases element types, so a coordinator built on it cannot
/// inspect what is currently on the stack — which rules out behaviors like
/// "pop back to the existing instance of this route instead of pushing a
/// duplicate". `TypedNavigationCoordinator` trades `NavigationPath`'s
/// mixed-type flexibility for full inspectability: apps with a single route
/// enum (the common case) lose nothing and gain `routes`, `popTo(_:)`, and
/// `pushOrPopTo(_:)`.
///
/// Pair with `TypedCoordinatedNavigationStack`, which binds `routes` to
/// `NavigationStack(path:)` directly. System-driven pops (back-swipe
/// gestures) mutate `routes` through that binding, so the array always
/// reflects the live stack.
///
/// Usage:
/// ```swift
/// enum AppRoute: Hashable {
///     case detail(id: String)
///     case settings
/// }
///
/// let coordinator = TypedNavigationCoordinator<AppRoute>()
/// coordinator.push(.detail(id: "123"))
/// coordinator.pushOrPopTo(.detail(id: "123")) // no duplicate; stays put
/// ```
@MainActor
public class TypedNavigationCoordinator<Route: Hashable>: ObservableObject {
    /// The routes currently on the navigation stack, in push order.
    /// Bound to `NavigationStack(path:)` by `TypedCoordinatedNavigationStack`.
    @Published public var routes: [Route] = []

    /// The currently presented modal, if any.
    @Published public var activeModal: ModalPresentation<Route>?

    private let logger: Logger

    public init(loggerSubsystem: String = "com.sharedkit") {
        logger = Logger(subsystem: loggerSubsystem, category: "TypedNavigationCoordinator")
    }

    /// Push a route onto the navigation stack.
    public func push(_ route: Route) {
        logger.debug("Push: \(String(describing: route), privacy: .public)")
        routes.append(route)
    }

    /// Pop the top route from the navigation stack.
    public func pop() {
        guard !routes.isEmpty else {
            logger.debug("Pop ignored — stack is empty")
            return
        }
        logger.debug("Pop")
        routes.removeLast()
    }

    /// Pop to the root of the navigation stack.
    public func popToRoot() {
        guard !routes.isEmpty else { return }
        logger.debug("Pop to root (depth: \(self.routes.count))")
        routes = []
    }

    /// Pop back to the most recent occurrence of `route` on the stack,
    /// removing everything above it.
    ///
    /// - Returns: `true` when the route was found (including when it is
    ///   already the top of the stack, a no-op); `false` when it is not on
    ///   the stack, in which case the stack is unchanged.
    @discardableResult
    public func popTo(_ route: Route) -> Bool {
        guard let index = routes.lastIndex(of: route) else {
            logger.debug("PopTo ignored — route not on stack: \(String(describing: route), privacy: .public)")
            return false
        }
        logger.debug("PopTo: \(String(describing: route), privacy: .public) (removing \(self.routes.count - index - 1))")
        routes.removeSubrange(routes.index(after: index)...)
        return true
    }

    /// Push `route`, unless it is already on the stack — then pop back to the
    /// existing occurrence instead.
    ///
    /// Use this for navigation graphs with cycles (A → B → A …) to keep the
    /// stack bounded by the set of distinct routes visited rather than
    /// growing without limit.
    public func pushOrPopTo(_ route: Route) {
        if !popTo(route) {
            push(route)
        }
    }

    /// Present a route modally as a sheet or full-screen cover.
    public func present(_ route: Route, style: PresentationStyle) {
        if activeModal != nil {
            logger.warning("Replacing active modal — dismiss first to ensure clean animation transitions")
        }
        logger.debug("Present \(String(describing: style)): \(String(describing: route), privacy: .public)")
        activeModal = ModalPresentation(route: route, style: style)
    }

    /// Dismiss the currently presented modal.
    public func dismissModal() {
        guard activeModal != nil else { return }
        logger.debug("Dismiss modal")
        activeModal = nil
    }
}

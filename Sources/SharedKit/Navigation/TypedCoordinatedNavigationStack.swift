import SwiftUI

/// A `NavigationStack` wrapper that binds to a `TypedNavigationCoordinator`
/// and automatically handles sheet and full-screen cover presentations.
///
/// The typed counterpart of `CoordinatedNavigationStack`: the stack binds
/// directly to the coordinator's `[Route]` array, so system-driven pops
/// (back-swipe gestures) keep `coordinator.routes` in sync and the app can
/// inspect the live stack at any time.
///
/// Usage:
/// ```swift
/// @StateObject var coordinator = TypedNavigationCoordinator<AppRoute>()
///
/// TypedCoordinatedNavigationStack(coordinator: coordinator) { route in
///     switch route {
///     case .detail(let id):
///         DetailView(id: id)
///     case .settings:
///         SettingsView()
///     }
///  } root: {
///     HomeView()
///  }
/// ```
public struct TypedCoordinatedNavigationStack<Route: Hashable, Destination: View, Root: View>: View {
    @ObservedObject private var coordinator: TypedNavigationCoordinator<Route>
    private let destination: (Route) -> Destination
    private let root: () -> Root

    public init(
        coordinator: TypedNavigationCoordinator<Route>,
        @ViewBuilder destination: @escaping (Route) -> Destination,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.destination = destination
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: $coordinator.routes) {
            root()
                .navigationDestination(for: Route.self, destination: destination)
        }
        .sheet(
            item: sheetBinding,
            content: { modal in destination(modal.route) }
        )
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        .fullScreenCover(
            item: fullScreenCoverBinding,
            content: { modal in destination(modal.route) }
        )
        #endif
    }

    // MARK: - Private

    private var sheetBinding: Binding<ModalPresentation<Route>?> {
        Binding(
            get: {
                guard let modal = coordinator.activeModal, modal.style == .sheet else {
                    return nil
                }
                return modal
            },
            set: { newValue in
                if newValue == nil { coordinator.dismissModal() }
            }
        )
    }

    private var fullScreenCoverBinding: Binding<ModalPresentation<Route>?> {
        Binding(
            get: {
                guard let modal = coordinator.activeModal, modal.style == .fullScreenCover else {
                    return nil
                }
                return modal
            },
            set: { newValue in
                if newValue == nil { coordinator.dismissModal() }
            }
        )
    }
}

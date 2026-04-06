import SwiftUI

/// A `NavigationStack` wrapper that binds to a `NavigationCoordinator`
/// and automatically handles sheet and full-screen cover presentations.
///
/// Consumers supply a `@ViewBuilder` closure to resolve routes into views,
/// which is used for both `navigationDestination` and modal content.
///
/// Usage:
/// ```swift
/// @StateObject var coordinator = NavigationCoordinator<AppRoute>()
///
/// CoordinatedNavigationStack(coordinator: coordinator) { route in
///     switch route {
///     case .detail(let id):
///         DetailView(id: id)
///     case .settings:
///         SettingsView()
///     case .profile:
///         ProfileView()
///     }
///  } root: {
///     HomeView()
///  }
/// ```
public struct CoordinatedNavigationStack<Route: Hashable, Destination: View, Root: View>: View {
    @ObservedObject private var coordinator: NavigationCoordinator<Route>
    private let destination: (Route) -> Destination
    private let root: () -> Root

    public init(
        coordinator: NavigationCoordinator<Route>,
        @ViewBuilder destination: @escaping (Route) -> Destination,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.destination = destination
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
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

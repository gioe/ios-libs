import SwiftUI

/// View modifier to inject a `NavigationCoordinator` into the SwiftUI environment.
///
/// Usage:
/// ```swift
/// ContentView()
///     .navigationCoordinator(coordinator)
/// ```
public extension View {
    func navigationCoordinator<Route: Hashable>(
        _ coordinator: NavigationCoordinator<Route>
    ) -> some View {
        environmentObject(coordinator)
    }
}

import SwiftUI

private struct APIClientFactoryKey: EnvironmentKey {
    static let defaultValue: APIClientFactory? = nil
}

public extension EnvironmentValues {
    /// The shared API client factory. Inject at the app root so views and view models
    /// can access a pre-configured client without recreating it on each call.
    ///
    /// ```swift
    /// // At the app root:
    /// let factory = APIClientFactory(serverURL: URL(string: "https://api.example.com")!)
    /// ContentView()
    ///     .environment(\.apiClientFactory, factory)
    ///
    /// // In any view:
    /// @Environment(\.apiClientFactory) private var apiClientFactory
    /// ```
    var apiClientFactory: APIClientFactory? {
        get { self[APIClientFactoryKey.self] }
        set { self[APIClientFactoryKey.self] = newValue }
    }
}

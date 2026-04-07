import Foundation
import SwiftUI

// MARK: - Service Scope

/// Determines lifetime behavior when resolving a dependency.
public enum ServiceScope {
    /// One instance per container, created on first resolution and reused thereafter.
    case appLevel
    /// A new instance is created on every resolution.
    case featureLevel
}

// MARK: - Service Registration

private struct ServiceRegistration {
    let scope: ServiceScope
    let factory: () -> Any
}

// MARK: - ServiceContainer

/// A lightweight dependency injection container supporting registration, resolution, and scoping.
///
/// Usage:
/// ```swift
/// let container = ServiceContainer()
/// container.register(NetworkMonitorProtocol.self, scope: .appLevel) { NetworkMonitor() }
/// container.register(ToastManagerProtocol.self, scope: .featureLevel) { ToastManager() }
///
/// let monitor: NetworkMonitorProtocol = container.resolve()
/// ```
///
/// Inject into the SwiftUI environment to enable `@Injected` property wrapper access in previews:
/// ```swift
/// ContentView()
///     .environment(\.serviceContainer, container)
/// ```
public final class ServiceContainer: @unchecked Sendable {
    private var registrations: [ObjectIdentifier: ServiceRegistration] = [:]
    private var singletons: [ObjectIdentifier: Any] = [:]
    private let lock = NSRecursiveLock()
    private var parent: ServiceContainer?

    /// The shared app-level container.
    public static let shared = ServiceContainer()

    public init() {}

    /// Creates a child container that inherits registrations from this container.
    ///
    /// Resolutions check the child first, then fall back to the parent.
    /// App-level singletons in the parent are shared; overrides in the child get their own scope.
    public func makeChildContainer() -> ServiceContainer {
        let child = ServiceContainer()
        child.parent = self
        return child
    }

    /// Registers a pre-created instance for a given service type.
    ///
    /// This is a convenience for registering an already-instantiated service. The instance is
    /// captured in a factory closure and behaves identically to a factory registration.
    ///
    /// - Parameters:
    ///   - type: The protocol or type to register.
    ///   - scope: `.appLevel` for singleton behavior, `.featureLevel` for a new instance each time.
    ///   - instance: The pre-created instance to register.
    public func register<T>(_ type: T.Type, scope: ServiceScope = .appLevel, instance: T) {
        register(type, scope: scope) { instance }
    }

    /// Registers a factory for a given service type.
    ///
    /// - Parameters:
    ///   - type: The protocol or type to register.
    ///   - scope: `.appLevel` for singleton behavior, `.featureLevel` for a new instance each time.
    ///   - factory: A closure that produces an instance of the service.
    public func register<T>(_ type: T.Type, scope: ServiceScope = .appLevel, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        registrations[key] = ServiceRegistration(scope: scope, factory: factory)
        // Clear cached singleton if re-registering
        singletons.removeValue(forKey: key)
    }

    /// Resolves a registered service, returning an instance according to its scope.
    ///
    /// - Returns: An instance of the requested type.
    /// - Note: Fatal error if the type was never registered (and no parent has it).
    public func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = ObjectIdentifier(type)

        lock.lock()
        if let registration = registrations[key] {
            let result: T = resolveRegistration(registration, key: key)
            lock.unlock()
            return result
        }
        let parent = self.parent
        lock.unlock()

        if let parent {
            return parent.resolve(type)
        }

        fatalError("No registration found for \(T.self). Call register(_:scope:factory:) before resolving.")
    }

    /// Resolves a registered service, returning `nil` if not registered.
    public func resolveOptional<T>(_ type: T.Type = T.self) -> T? {
        let key = ObjectIdentifier(type)

        lock.lock()
        if let registration = registrations[key] {
            let result: T = resolveRegistration(registration, key: key)
            lock.unlock()
            return result
        }
        let parent = self.parent
        lock.unlock()

        return parent?.resolveOptional(type)
    }

    private func resolveRegistration<T>(_ registration: ServiceRegistration, key: ObjectIdentifier) -> T {
        switch registration.scope {
        case .appLevel:
            if let existing = singletons[key] as? T {
                return existing
            }
            let instance = registration.factory() as! T
            singletons[key] = instance
            return instance
        case .featureLevel:
            return registration.factory() as! T
        }
    }

    /// Removes all registrations and cached singletons.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        registrations.removeAll()
        singletons.removeAll()
    }
}

// MARK: - SwiftUI Environment Integration

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer = .shared
}

public extension EnvironmentValues {
    /// The service container available in the current SwiftUI environment.
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - @Injected Property Wrapper

/// A property wrapper that resolves a dependency from the shared `ServiceContainer`.
///
/// ```swift
/// class MyViewModel: BaseViewModel {
///     @Injected var networkMonitor: NetworkMonitorProtocol
/// }
/// ```
///
/// By default resolves from `ServiceContainer.shared`. For SwiftUI views,
/// prefer using `@Environment(\.serviceContainer)` to access a view-hierarchy-specific container.
@propertyWrapper
public struct Injected<T> {
    private let container: ServiceContainer

    public init(container: ServiceContainer = .shared) {
        self.container = container
    }

    public var wrappedValue: T {
        container.resolve()
    }
}

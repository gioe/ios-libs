import Foundation
import Testing
@testable import SharedKit

// MARK: - Test Protocols

private protocol GreetingService {
    var greeting: String { get }
}

private final class HelloService: GreetingService {
    let greeting = "Hello"
}

private final class HolaService: GreetingService {
    let greeting = "Hola"
}

private protocol CounterService {
    var id: String { get }
}

private final class SimpleCounter: CounterService {
    let id = UUID().uuidString
}

// MARK: - Registration & Resolution

@Suite("ServiceContainer")
struct ServiceContainerTests {

    @Test("Registers and resolves a dependency")
    func registerAndResolve() {
        let container = ServiceContainer()
        container.register(GreetingService.self) { HelloService() }

        let service: GreetingService = container.resolve()
        #expect(service.greeting == "Hello")
    }

    @Test("Fatal error on unregistered type")
    func resolveUnregistered() {
        let container = ServiceContainer()
        let result: GreetingService? = container.resolveOptional()
        #expect(result == nil)
    }

    @Test("App-level scope returns same instance")
    func appLevelScope() {
        let container = ServiceContainer()
        container.register(CounterService.self, scope: .appLevel) { SimpleCounter() }

        let a: CounterService = container.resolve()
        let b: CounterService = container.resolve()
        #expect(a.id == b.id)
    }

    @Test("Feature-level scope returns new instance each time")
    func featureLevelScope() {
        let container = ServiceContainer()
        container.register(CounterService.self, scope: .featureLevel) { SimpleCounter() }

        let a: CounterService = container.resolve()
        let b: CounterService = container.resolve()
        #expect(a.id != b.id)
    }

    @Test("Re-registration clears cached singleton")
    func reRegistration() {
        let container = ServiceContainer()
        container.register(GreetingService.self) { HelloService() }
        let first: GreetingService = container.resolve()
        #expect(first.greeting == "Hello")

        container.register(GreetingService.self) { HolaService() }
        let second: GreetingService = container.resolve()
        #expect(second.greeting == "Hola")
    }

    @Test("Reset clears all registrations")
    func reset() {
        let container = ServiceContainer()
        container.register(GreetingService.self) { HelloService() }
        container.reset()

        let result: GreetingService? = container.resolveOptional()
        #expect(result == nil)
    }

    // MARK: - Child Containers

    @Test("Child container inherits parent registrations")
    func childInheritsParent() {
        let parent = ServiceContainer()
        parent.register(GreetingService.self) { HelloService() }

        let child = parent.makeChildContainer()
        let service: GreetingService = child.resolve()
        #expect(service.greeting == "Hello")
    }

    @Test("Child container overrides parent registration")
    func childOverridesParent() {
        let parent = ServiceContainer()
        parent.register(GreetingService.self) { HelloService() }

        let child = parent.makeChildContainer()
        child.register(GreetingService.self) { HolaService() }

        let parentService: GreetingService = parent.resolve()
        let childService: GreetingService = child.resolve()

        #expect(parentService.greeting == "Hello")
        #expect(childService.greeting == "Hola")
    }

    @Test("Child resolveOptional falls back to parent")
    func childOptionalFallback() {
        let parent = ServiceContainer()
        parent.register(GreetingService.self) { HelloService() }

        let child = parent.makeChildContainer()
        let result: GreetingService? = child.resolveOptional()
        #expect(result != nil)
        #expect(result?.greeting == "Hello")
    }

    // MARK: - @Injected Property Wrapper

    @Test("Injected property wrapper resolves from container")
    func injectedWrapper() {
        let container = ServiceContainer()
        container.register(GreetingService.self) { HelloService() }

        struct Consumer {
            @Injected var service: GreetingService

            init(container: ServiceContainer) {
                _service = Injected(container: container)
            }
        }

        let consumer = Consumer(container: container)
        #expect(consumer.service.greeting == "Hello")
    }

    // MARK: - Concurrency

    @Test("Concurrent resolves are thread-safe")
    func concurrentResolves() {
        let container = ServiceContainer()
        container.register(CounterService.self, scope: .featureLevel) { SimpleCounter() }

        let iterations = 1000
        var results = [String?](repeating: nil, count: iterations)

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let service: CounterService = container.resolve()
            results[i] = service.id
        }

        let nonNil = results.compactMap { $0 }
        #expect(nonNil.count == iterations)
    }

    @Test("Factory that resolves transitive dependency does not deadlock")
    func transitiveDependency() {
        let container = ServiceContainer()
        container.register(CounterService.self) { SimpleCounter() }
        container.register(GreetingService.self) {
            // Resolve a transitive dependency inside the factory
            let _: CounterService = container.resolve()
            return HelloService()
        }

        let service: GreetingService = container.resolve()
        #expect(service.greeting == "Hello")
    }
}

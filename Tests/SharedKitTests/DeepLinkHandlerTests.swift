import Foundation
import Testing
@testable import SharedKit

// MARK: - Test Types

private enum TestRoute: Hashable {
    case home
    case detail(id: String)
    case settings
    case profile
}

private struct TestParser: DeepLinkParser {
    func parse(url: URL) -> DeepLinkAction<TestRoute>? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let path = components.path
        let queryItems = components.queryItems ?? []

        switch path {
        case "/home":
            return .popToRootThenPush(.home)
        case "/detail":
            guard let id = queryItems.first(where: { $0.name == "id" })?.value else {
                return nil
            }
            return .push(.detail(id: id))
        case "/settings":
            return .present(.settings, style: .sheet)
        case "/profile":
            return .present(.profile, style: .fullScreenCover)
        default:
            return nil
        }
    }
}

// MARK: - DeepLinkHandler Tests

@Suite("DeepLinkHandler")
@MainActor
struct DeepLinkHandlerTests {

    private let coordinator = NavigationCoordinator<TestRoute>()
    private let parser = TestParser()

    private var handler: DeepLinkHandler<TestParser> {
        DeepLinkHandler(coordinator: coordinator, parser: parser)
    }

    // MARK: - Push

    @Test("Handle push deep link appends route to path")
    func handlePush() {
        let handler = handler
        let url = URL(string: "myapp://app/detail?id=42")!

        let handled = handler.handle(url: url)

        #expect(handled == true)
        #expect(coordinator.path.count == 1)
    }

    // MARK: - Present

    @Test("Handle present deep link sets activeModal with sheet style")
    func handlePresentSheet() throws {
        let handler = handler
        let url = URL(string: "myapp://app/settings")!

        let handled = handler.handle(url: url)

        #expect(handled == true)
        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .settings)
        #expect(modal.style == .sheet)
    }

    @Test("Handle present deep link sets activeModal with fullScreenCover style")
    func handlePresentFullScreen() throws {
        let handler = handler
        let url = URL(string: "myapp://app/profile")!

        let handled = handler.handle(url: url)

        #expect(handled == true)
        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .profile)
        #expect(modal.style == .fullScreenCover)
    }

    // MARK: - Pop to Root Then Push

    @Test("Handle popToRootThenPush clears path then pushes")
    func handlePopToRootThenPush() {
        let handler = handler
        coordinator.push(.settings)
        coordinator.push(.profile)
        #expect(coordinator.path.count == 2)

        let url = URL(string: "myapp://app/home")!
        let handled = handler.handle(url: url)

        #expect(handled == true)
        #expect(coordinator.path.count == 1)
    }

    // MARK: - Unrecognized URLs

    @Test("Handle returns false for unrecognized URL")
    func handleUnrecognized() {
        let handler = handler
        let url = URL(string: "myapp://app/unknown")!

        let handled = handler.handle(url: url)

        #expect(handled == false)
        #expect(coordinator.path.count == 0)
        #expect(coordinator.activeModal == nil)
    }

    @Test("Handle returns false for URL with missing required parameter")
    func handleMissingParameter() {
        let handler = handler
        let url = URL(string: "myapp://app/detail")!

        let handled = handler.handle(url: url)

        #expect(handled == false)
    }

    // MARK: - Universal Links

    @Test("Handle parses universal link URLs")
    func handleUniversalLink() {
        let handler = handler
        let url = URL(string: "https://example.com/detail?id=99")!

        let handled = handler.handle(url: url)

        #expect(handled == true)
        #expect(coordinator.path.count == 1)
    }

    // MARK: - Coordinator State Independence

    @Test("Push deep link does not affect modal state")
    func pushDoesNotAffectModal() throws {
        let handler = handler
        coordinator.present(.settings, style: .sheet)

        let url = URL(string: "myapp://app/detail?id=1")!
        handler.handle(url: url)

        #expect(coordinator.path.count == 1)
        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .settings)
    }

    @Test("Present deep link does not affect stack state")
    func presentDoesNotAffectStack() throws {
        let handler = handler
        coordinator.push(.home)

        let url = URL(string: "myapp://app/settings")!
        handler.handle(url: url)

        #expect(coordinator.path.count == 1)
        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .settings)
    }

    @Test("Multiple deep links handled sequentially")
    func multipleDeepLinks() {
        let handler = handler

        handler.handle(url: URL(string: "myapp://app/detail?id=1")!)
        handler.handle(url: URL(string: "myapp://app/detail?id=2")!)

        #expect(coordinator.path.count == 2)
    }

    // MARK: - Concurrent Processing Guard

    @Test("Concurrent deep link processing guard drops second link while first is in progress")
    func concurrentProcessingGuard() async {
        let handler = handler

        // First deep link — slow async work keeps isProcessingDeepLink set
        let first = Task { @MainActor in
            await handler.handle(url: URL(string: "myapp://app/detail?id=1")!) {
                // Yield the main actor while still "processing"
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        // Second deep link — should be dropped because first is still processing
        let second = Task { @MainActor in
            await handler.handle(url: URL(string: "myapp://app/detail?id=2")!)
        }

        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult == true)
        #expect(secondResult == false)
        #expect(handler.isProcessingDeepLink == false)
        // Only the first link's route should be in the path
        #expect(coordinator.path.count == 1)
    }
}

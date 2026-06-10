import Foundation
import Testing
@testable import SharedKit

// MARK: - Test Route

private enum TestRoute: Hashable {
    case home
    case detail(id: String)
    case settings
    case profile
}

// MARK: - TypedNavigationCoordinator Tests

@Suite("TypedNavigationCoordinator")
@MainActor
struct TypedNavigationCoordinatorTests {

    @Test("Push appends route in push order")
    func push() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.detail(id: "abc"))
        #expect(coordinator.routes == [.home, .detail(id: "abc")])
    }

    @Test("Pop removes last route")
    func pop() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)

        coordinator.pop()
        #expect(coordinator.routes == [.home])
    }

    @Test("Pop on empty stack is a no-op")
    func popEmpty() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.pop()
        #expect(coordinator.routes.isEmpty)
    }

    @Test("PopToRoot clears the entire stack")
    func popToRoot() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.detail(id: "1"))
        coordinator.push(.settings)

        coordinator.popToRoot()
        #expect(coordinator.routes.isEmpty)
    }

    @Test("PopToRoot on empty stack is a no-op")
    func popToRootEmpty() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.popToRoot()
        #expect(coordinator.routes.isEmpty)
    }

    @Test("PopTo removes everything above the target route")
    func popTo() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.detail(id: "1"))
        coordinator.push(.settings)
        coordinator.push(.profile)

        let found = coordinator.popTo(.detail(id: "1"))
        #expect(found)
        #expect(coordinator.routes == [.home, .detail(id: "1")])
    }

    @Test("PopTo the top route is a found no-op")
    func popToTop() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)

        let found = coordinator.popTo(.settings)
        #expect(found)
        #expect(coordinator.routes == [.home, .settings])
    }

    @Test("PopTo a route not on the stack leaves the stack unchanged")
    func popToMissing() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)

        let found = coordinator.popTo(.profile)
        #expect(!found)
        #expect(coordinator.routes == [.home, .settings])
    }

    @Test("PopTo targets the most recent occurrence of a repeated route")
    func popToMostRecentOccurrence() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)
        coordinator.push(.home)
        coordinator.push(.profile)

        coordinator.popTo(.home)
        #expect(coordinator.routes == [.home, .settings, .home])
    }

    @Test("PushOrPopTo pushes a route not on the stack")
    func pushOrPopToPushes() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)

        coordinator.pushOrPopTo(.settings)
        #expect(coordinator.routes == [.home, .settings])
    }

    @Test("PushOrPopTo pops back to an existing route instead of duplicating")
    func pushOrPopToDeduplicates() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.detail(id: "club"))
        coordinator.push(.detail(id: "show"))
        coordinator.push(.detail(id: "comedian"))

        coordinator.pushOrPopTo(.detail(id: "club"))
        #expect(coordinator.routes == [.detail(id: "club")])
    }

    @Test("PushOrPopTo with the current top route stays put")
    func pushOrPopToCurrentTop() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)

        coordinator.pushOrPopTo(.settings)
        #expect(coordinator.routes == [.home, .settings])
    }

    @Test("Present sets activeModal with sheet style")
    func presentSheet() throws {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.present(.settings, style: .sheet)

        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .settings)
        #expect(modal.style == .sheet)
    }

    @Test("Present sets activeModal with fullScreenCover style")
    func presentFullScreenCover() throws {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.present(.profile, style: .fullScreenCover)

        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .profile)
        #expect(modal.style == .fullScreenCover)
    }

    @Test("DismissModal clears activeModal")
    func dismissModal() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.present(.settings, style: .sheet)
        #expect(coordinator.activeModal != nil)

        coordinator.dismissModal()
        #expect(coordinator.activeModal == nil)
    }

    @Test("Push and present are independent")
    func pushAndPresentIndependent() {
        let coordinator = TypedNavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.present(.settings, style: .sheet)

        #expect(coordinator.routes.count == 1)
        #expect(coordinator.activeModal != nil)

        coordinator.popToRoot()
        #expect(coordinator.routes.isEmpty)
        #expect(coordinator.activeModal != nil)

        coordinator.dismissModal()
        #expect(coordinator.activeModal == nil)
    }
}

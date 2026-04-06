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

// MARK: - NavigationCoordinator Tests

@Suite("NavigationCoordinator")
@MainActor
struct NavigationCoordinatorTests {

    @Test("Push appends route to path")
    func push() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        #expect(coordinator.path.count == 1)

        coordinator.push(.detail(id: "abc"))
        #expect(coordinator.path.count == 2)
    }

    @Test("Pop removes last route from path")
    func pop() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.settings)
        #expect(coordinator.path.count == 2)

        coordinator.pop()
        #expect(coordinator.path.count == 1)
    }

    @Test("Pop on empty path is a no-op")
    func popEmpty() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.pop()
        #expect(coordinator.path.count == 0)
    }

    @Test("PopToRoot clears the entire path")
    func popToRoot() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.push(.detail(id: "1"))
        coordinator.push(.settings)
        #expect(coordinator.path.count == 3)

        coordinator.popToRoot()
        #expect(coordinator.path.count == 0)
    }

    @Test("PopToRoot on empty path is a no-op")
    func popToRootEmpty() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.popToRoot()
        #expect(coordinator.path.count == 0)
    }

    @Test("Present sets activeModal with sheet style")
    func presentSheet() throws {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.present(.settings, style: .sheet)

        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .settings)
        #expect(modal.style == .sheet)
    }

    @Test("Present sets activeModal with fullScreenCover style")
    func presentFullScreenCover() throws {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.present(.profile, style: .fullScreenCover)

        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .profile)
        #expect(modal.style == .fullScreenCover)
    }

    @Test("Present replaces existing modal")
    func presentReplacesModal() throws {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.present(.settings, style: .sheet)
        coordinator.present(.profile, style: .fullScreenCover)

        let modal = try #require(coordinator.activeModal)
        #expect(modal.route == .profile)
        #expect(modal.style == .fullScreenCover)
    }

    @Test("DismissModal clears activeModal")
    func dismissModal() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.present(.settings, style: .sheet)
        #expect(coordinator.activeModal != nil)

        coordinator.dismissModal()
        #expect(coordinator.activeModal == nil)
    }

    @Test("DismissModal when no modal is a no-op")
    func dismissModalNoModal() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.dismissModal()
        #expect(coordinator.activeModal == nil)
    }

    @Test("Push and present are independent")
    func pushAndPresentIndependent() {
        let coordinator = NavigationCoordinator<TestRoute>()
        coordinator.push(.home)
        coordinator.present(.settings, style: .sheet)

        #expect(coordinator.path.count == 1)
        #expect(coordinator.activeModal != nil)

        coordinator.popToRoot()
        #expect(coordinator.path.count == 0)
        #expect(coordinator.activeModal != nil)

        coordinator.dismissModal()
        #expect(coordinator.activeModal == nil)
    }

    @Test("ModalPresentation has unique IDs")
    func modalPresentationIds() {
        let a = ModalPresentation(route: TestRoute.home, style: .sheet)
        let b = ModalPresentation(route: TestRoute.home, style: .sheet)
        #expect(a.id != b.id)
    }
}

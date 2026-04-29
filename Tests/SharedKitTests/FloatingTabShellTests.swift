import CoreGraphics
import SwiftUI
import Testing
@testable import SharedKit

@Suite("FloatingTabShell")
struct FloatingTabShellTests {
    @Test("layout adds top spacing to safe area")
    func layoutAddsTopSpacingToSafeArea() {
        let layout = FloatingTabShellLayout(headerTopSpacing: 6)

        #expect(layout.headerTopPadding(safeAreaTop: 59) == 65)
    }

    @Test("layout hides header on pushed routes by default")
    func layoutHidesHeaderOnPushedRoutesByDefault() {
        let layout = FloatingTabShellLayout()

        #expect(layout.showsHeaderWhenNavigating == false)
    }

    @Test("header context carries safe area root state and top padding")
    func headerContextCarriesLayoutInputs() {
        let context = FloatingTabShellHeaderContext(
            safeAreaTopInset: 47,
            isAtRoot: true,
            topPadding: 51
        )

        #expect(context.safeAreaTopInset == 47)
        #expect(context.isAtRoot)
        #expect(context.topPadding == 51)
    }
}

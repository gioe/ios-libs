import Foundation
import SharedKit
import XCTest

/// Base XCTestCase for App Store screenshot capture flows driven by
/// fastlane's `snapshot` tool.
///
/// Subclasses implement only the per-app navigation in
/// `testGenerateAllScreenshots()`. The base handles `XCUIApplication`
/// instantiation, the `-UITestMockMode` launch argument, and a
/// coordinate-based tap helper that bypasses XCUI's element queries.
///
/// ## Why coordinate taps
///
/// On iOS 18+, SwiftUI surfaces `Text()` and `Button` labels as
/// `accessibilityElements` on a parent UIView rather than as UIView
/// subviews. XCUI element queries like `app.tabBars.buttons["Search"]`,
/// `app.buttons["my-accessibility-id"]`, and `app.staticTexts["TONIGHT"]`
/// don't reliably resolve through that traversal. Coordinate-based taps
/// are brittle across devices but predictable for a single screenshot
/// device — and that single-device flow is what fastlane snapshot drives.
///
/// ## Required wiring
///
/// Apps must include fastlane's `SnapshotHelper.swift` in the same UI test
/// target. Override `prepareForSnapshot()` to call `setupSnapshot(app)` so
/// that `snapshot("name")` calls inside the test method actually capture.
/// The base class deliberately doesn't `import` the fastlane helper —
/// fastlane regenerates it on its own cadence and we don't want this
/// package to pin a copy.
///
/// ## Example
///
/// ```swift
/// @MainActor
/// final class AppStoreScreenshotTests: BaseAppStoreScreenshotTests {
///     override func prepareForSnapshot() {
///         setupSnapshot(app)
///     }
///
///     func testGenerateAllScreenshots() throws {
///         sleep(8); snapshot("01_Home")
///         tap(x: 220, y: 915); sleep(2); snapshot("02_Search")
///         // …
///     }
/// }
/// ```
@MainActor
open class BaseAppStoreScreenshotTests: XCTestCase {
    /// The application under test. Available after `setUpWithError()` runs.
    public var app: XCUIApplication!

    open override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        prepareForSnapshot()
        app.launchArguments.append(MockModeDetector.mockModeArgument)
        configureLaunchArguments()
        app.launch()
    }

    open override func tearDownWithError() throws {
        app = nil
    }

    /// Override to call `setupSnapshot(app)` from your local
    /// `SnapshotHelper.swift`. Default is a no-op so subclasses still launch
    /// in environments that don't link fastlane snapshot.
    open func prepareForSnapshot() {}

    /// Override to add additional launch arguments before `app.launch()`.
    /// Useful for app-specific test scenarios layered on top of mock mode
    /// (e.g. `-DisableScreenshotPrevention`, `-hasCompletedOnboarding`).
    open func configureLaunchArguments() {}

    /// Tap at absolute coordinates measured from the app window's top-left.
    ///
    /// Find target coordinates by capturing a screenshot of the app at the
    /// device size you're targeting (e.g. iPhone 16 Pro Max @ 440 × 956
    /// logical points) and reading the visual location of the tap target.
    public func tap(x: CGFloat, y: CGFloat) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: x, dy: y)).tap()
    }
}

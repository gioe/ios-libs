import Foundation

/// Detects whether the app process was launched in UI-test mock mode.
///
/// When `-UITestMockMode` is passed as a launch argument, the app should
/// configure deterministic state for UI test runs — typically pre-populating
/// caches, skipping permission prompts, or seeding services with fixed
/// values so tests don't depend on live network or device state.
///
/// ## Usage from a UI test
/// ```swift
/// app.launchArguments.append(MockModeDetector.mockModeArgument)
/// app.launch()
/// ```
///
/// ## Usage from app code
/// ```swift
/// init() {
///     // ... regular bootstrap ...
///     if MockModeDetector.isMockMode {
///         seedMockState()
///     }
/// }
/// ```
///
/// The detector intentionally exposes only the launch-arg check. Apps that
/// need richer scenario routing (e.g. distinct mock data sets per test) can
/// layer their own scenario enum on top by reading additional launch
/// arguments or environment variables. Keeping this type minimal lets every
/// consumer adopt the same `-UITestMockMode` convention without inheriting
/// scenario semantics they don't need.
public enum MockModeDetector {
    /// The launch argument that enables mock mode.
    public static let mockModeArgument = "-UITestMockMode"

    /// Returns `true` when the app process was launched with
    /// `-UITestMockMode`. Implemented via `ProcessInfo.processInfo.arguments`,
    /// which captures launch arguments passed by `XCUIApplication.launch()`,
    /// `xcrun simctl launch`, and Xcode scheme arguments.
    public static var isMockMode: Bool {
        ProcessInfo.processInfo.arguments.contains(mockModeArgument)
    }
}

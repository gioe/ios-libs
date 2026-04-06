import Foundation
import SwiftUI
@testable import SharedKit
import Testing

@Suite("NetworkStatusBanner")
struct NetworkStatusBannerTests {

    // MARK: - Initialization & Configuration

    @Test("default init uses expected default message")
    func defaultMessage() {
        let banner = NetworkStatusBanner()
        #expect(banner.message == "No network connection")
    }

    @Test("custom message is stored")
    func customMessage() {
        let banner = NetworkStatusBanner(message: "You are offline")
        #expect(banner.message == "You are offline")
    }

    @Test("custom background color is stored")
    func customBackgroundColor() {
        let banner = NetworkStatusBanner(backgroundColor: .red)
        #expect(banner.backgroundColor == .red)
    }

    @Test("custom text color is stored")
    func customTextColor() {
        let banner = NetworkStatusBanner(textColor: .black)
        #expect(banner.textColor == .black)
    }

    @Test("nil colors default to nil (resolved via theme at render time)")
    func nilColorsDefault() {
        let banner = NetworkStatusBanner()
        #expect(banner.backgroundColor == nil)
        #expect(banner.textColor == nil)
    }

    @Test("accepts a custom monitor instance")
    func customMonitor() {
        let monitor = NetworkMonitor()
        defer { monitor.stopMonitoring() }
        let banner = NetworkStatusBanner(monitor: monitor)
        #expect(banner.message == "No network connection")
    }

    // MARK: - Visibility (connected state)

    @Test("body renders without error when monitor is connected")
    @MainActor
    func bodyWhenConnected() {
        // NetworkMonitor initializes with isConnected = true.
        // The banner's `if` guard hides content when connected.
        let monitor = NetworkMonitor()
        defer { monitor.stopMonitoring() }
        let banner = NetworkStatusBanner(monitor: monitor)
        _ = banner.body
    }

    // MARK: - View modifier

    @Test("networkStatusBanner modifier compiles and returns a view")
    @MainActor
    func viewModifier() {
        let view = Text("Hello").networkStatusBanner()
        _ = view
    }

    @Test("networkStatusBanner modifier accepts custom parameters")
    @MainActor
    func viewModifierCustomParams() {
        let view = Text("Hello").networkStatusBanner(
            message: "Offline",
            backgroundColor: .red,
            textColor: .white
        )
        _ = view
    }
}

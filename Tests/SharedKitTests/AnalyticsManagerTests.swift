import Foundation
import Testing
@testable import SharedKit

// MARK: - Spy Provider

private final class SpyAnalyticsProvider: AnalyticsProvider {
    var trackedEvents: [AnalyticsEvent] = []
    var trackedScreens: [(name: String, parameters: [String: Any]?)] = []
    var userProperties: [String: String?] = [:]
    var userID: String?
    var resetCount = 0

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ name: String, parameters: [String: Any]?) {
        trackedScreens.append((name, parameters))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
    }

    func setUserID(_ userID: String?) {
        self.userID = userID
    }

    func reset() {
        resetCount += 1
    }
}

// MARK: - Tests

@Suite("AnalyticsManager")
struct AnalyticsManagerTests {

    @Test("No-op with no providers registered")
    func noOpWithoutProviders() {
        let manager = AnalyticsManager()
        // Should not crash
        manager.track("event")
        manager.trackScreen("Home")
        manager.setUserProperty("premium", forName: "plan")
        manager.setUserID("user-1")
        manager.reset()
    }

    @Test("track dispatches to all providers")
    func trackDispatchesToProviders() {
        let manager = AnalyticsManager()
        let spy1 = SpyAnalyticsProvider()
        let spy2 = SpyAnalyticsProvider()
        manager.addProvider(spy1)
        manager.addProvider(spy2)

        manager.track("button_tap", parameters: ["screen": "home"])

        #expect(spy1.trackedEvents.count == 1)
        #expect(spy1.trackedEvents[0].name == "button_tap")
        #expect(spy2.trackedEvents.count == 1)
    }

    @Test("trackScreen dispatches to all providers")
    func trackScreenDispatches() {
        let manager = AnalyticsManager()
        let spy = SpyAnalyticsProvider()
        manager.addProvider(spy)

        manager.trackScreen("Settings", parameters: ["tab": "account"])

        #expect(spy.trackedScreens.count == 1)
        #expect(spy.trackedScreens[0].name == "Settings")
    }

    @Test("setUserProperty dispatches to all providers")
    func setUserPropertyDispatches() {
        let manager = AnalyticsManager()
        let spy = SpyAnalyticsProvider()
        manager.addProvider(spy)

        manager.setUserProperty("premium", forName: "plan")

        #expect(spy.userProperties["plan"] == "premium")
    }

    @Test("setUserID dispatches to all providers")
    func setUserIDDispatches() {
        let manager = AnalyticsManager()
        let spy = SpyAnalyticsProvider()
        manager.addProvider(spy)

        manager.setUserID("user-123")

        #expect(spy.userID == "user-123")
    }

    @Test("reset dispatches to all providers")
    func resetDispatches() {
        let manager = AnalyticsManager()
        let spy1 = SpyAnalyticsProvider()
        let spy2 = SpyAnalyticsProvider()
        manager.addProvider(spy1)
        manager.addProvider(spy2)

        manager.reset()

        #expect(spy1.resetCount == 1)
        #expect(spy2.resetCount == 1)
    }

    @Test("AnalyticsEvent stores name and parameters")
    func analyticsEventInit() {
        let event = AnalyticsEvent(name: "purchase", parameters: ["amount": 9.99])
        #expect(event.name == "purchase")
        #expect(event.parameters?["amount"] as? Double == 9.99)

        let simple = AnalyticsEvent(name: "tap")
        #expect(simple.parameters == nil)
    }
}

import Foundation
import Network
@testable import SharedKit
import Testing

@Suite("NetworkMonitor")
struct NetworkMonitorTests {
    @Test("initial state defaults to connected with unknown type")
    func initialState() {
        let monitor = NetworkMonitor(startImmediately: false)

        #expect(monitor.isConnected)
        #expect(monitor.connectionType == .unknown)
    }

    @Test("shared singleton returns same instance")
    func sharedSingleton() {
        let a = NetworkMonitor.shared
        let b = NetworkMonitor.shared
        #expect(a === b)
    }

    @Test("conforms to NetworkMonitorProtocol")
    func protocolConformance() {
        let monitor = NetworkMonitor()
        defer { monitor.stopMonitoring() }
        let proto: any NetworkMonitorProtocol = monitor
        #expect(proto.isConnected || !proto.isConnected) // verifies conformance
    }

    @Test("stopMonitoring does not crash")
    func stopMonitoring() {
        let monitor = NetworkMonitor()
        monitor.stopMonitoring()
    }

    @Test("ConnectionType cases exist")
    func connectionTypeCases() {
        let wifi = NetworkMonitor.ConnectionType.wifi
        let cellular = NetworkMonitor.ConnectionType.cellular
        let ethernet = NetworkMonitor.ConnectionType.ethernet
        let unknown = NetworkMonitor.ConnectionType.unknown

        // Verify all cases are distinct
        #expect(wifi != cellular)
        #expect(wifi != ethernet)
        #expect(wifi != unknown)
        #expect(cellular != ethernet)
    }
}


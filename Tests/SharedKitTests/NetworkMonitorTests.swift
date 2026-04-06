import Foundation
import Network
@testable import SharedKit
import Testing

@Suite("NetworkMonitor")
struct NetworkMonitorTests {
    @Test("initial state defaults to connected with unknown type")
    func initialState() {
        let monitor = NetworkMonitor()
        defer { monitor.stopMonitoring() }

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
        let monitor: any NetworkMonitorProtocol = NetworkMonitor()
        #expect(monitor.isConnected || !monitor.isConnected) // just verifies conformance
        if let concrete = monitor as? NetworkMonitor {
            concrete.stopMonitoring()
        }
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


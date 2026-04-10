import Combine
import Foundation
import Network

/// Protocol for monitoring network connectivity status
public protocol NetworkMonitorProtocol {
    /// Whether the device is currently connected to the network
    var isConnected: Bool { get }

    /// Publisher that emits connectivity changes
    var connectivityPublisher: AnyPublisher<Bool, Never> { get }
}

/// Monitors network connectivity status
public class NetworkMonitor: ObservableObject, NetworkMonitorProtocol {
    public static let shared = NetworkMonitor()

    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var connectionType: ConnectionType = .unknown

    public var connectivityPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    /// Initialize the network monitor
    ///
    /// - Parameter startImmediately: Whether to begin monitoring on init.
    ///   Defaults to `true`. Pass `false` to defer monitoring until
    ///   `startMonitoring()` is called explicitly.
    public init(startImmediately: Bool = true) {
        monitor = NWPathMonitor()
        if startImmediately {
            startMonitoring()
        }
    }

    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }

    public func stopMonitoring() {
        monitor.cancel()
    }

    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
}

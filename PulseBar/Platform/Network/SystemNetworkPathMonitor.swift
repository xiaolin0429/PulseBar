import Foundation
import Network

public struct NetworkPathState: Sendable, Equatable {
    public let status: NetworkPathStatus
    public let interfaceKind: NetworkInterfaceKind

    public init(status: NetworkPathStatus, interfaceKind: NetworkInterfaceKind) {
        self.status = status
        self.interfaceKind = interfaceKind
    }

    public static let unknown = NetworkPathState(status: .unknown, interfaceKind: .unknown)
}

public protocol NetworkPathReading: Sendable {
    func currentPath() async -> NetworkPathState
}

public actor SystemNetworkPathMonitor: NetworkPathReading {
    private var monitor: NWPathMonitor?
    private var state = NetworkPathState.unknown

    public init() {}

    public func currentPath() -> NetworkPathState {
        startIfNeeded()
        return state
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
        state = .unknown
    }

    private func startIfNeeded() {
        guard monitor == nil else { return }
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            let next = NetworkPathState(
                status: Self.status(from: path),
                interfaceKind: Self.interfaceKind(from: path)
            )
            Task { await self?.update(next) }
        }
        monitor = newMonitor
        newMonitor.start(queue: DispatchQueue(label: "com.pulsebar.network-path", qos: .utility))
    }

    private func update(_ next: NetworkPathState) {
        state = next
    }

    private nonisolated static func status(from path: NWPath) -> NetworkPathStatus {
        switch path.status {
        case .satisfied: .online
        case .unsatisfied: .offline
        case .requiresConnection: .requiresConnection
        @unknown default: .unknown
        }
    }

    private nonisolated static func interfaceKind(from path: NWPath) -> NetworkInterfaceKind {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.loopback) { return .other }
        return .unknown
    }
}

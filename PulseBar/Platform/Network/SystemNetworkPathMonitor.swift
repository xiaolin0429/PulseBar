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

    /// 首次读取时启动路径监听，立即返回缓存值而不等待首个系统回调。
    public func currentPath() -> NetworkPathState {
        startIfNeeded()
        return state
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
        state = .unknown
    }

    /// 注册单个后台路径监听，把系统回调转换为可跨并发域传递的轻量状态。
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

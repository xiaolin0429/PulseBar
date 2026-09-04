import Foundation
import Network

public struct NetworkPathState: Sendable, Equatable {
    public let status: NetworkPathStatus
    public let interfaceKind: NetworkInterfaceKind

    /// 保存网络可达性和接口类型，不包含地址或流量计数。
    public init(status: NetworkPathStatus, interfaceKind: NetworkInterfaceKind) {
        self.status = status
        self.interfaceKind = interfaceKind
    }

    public static let unknown = NetworkPathState(status: .unknown, interfaceKind: .unknown)
}

public protocol NetworkPathReading: Sendable {
    /// 获取最近的网络路径状态；尚无结果时允许返回 unknown。
    func currentPath() async -> NetworkPathState
}

public actor SystemNetworkPathMonitor: NetworkPathReading {
    private var monitor: NWPathMonitor?
    private var state = NetworkPathState.unknown

    /// 创建惰性路径监听器，直到首次读取才启动系统监听。
    public init() {}

    /// 首次读取时启动路径监听，立即返回缓存值而不等待首个系统回调。
    public func currentPath() -> NetworkPathState {
        startIfNeeded()
        return state
    }

    /// 停止路径监听并重置为未知状态，后续读取可以重新启动。
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

    /// 在 actor 内替换缓存，串行处理来自系统回调的状态更新。
    private func update(_ next: NetworkPathState) {
        state = next
    }

    /// 将系统路径可达性映射为业务状态；未来新增状态安全回退为 unknown。
    private nonisolated static func status(from path: NWPath) -> NetworkPathStatus {
        switch path.status {
        case .satisfied: .online
        case .unsatisfied: .offline
        case .requiresConnection: .requiresConnection
        @unknown default: .unknown
        }
    }

    /// 按 Wi-Fi、有线、蜂窝、回环顺序识别路径类型，无法识别时返回 unknown。
    private nonisolated static func interfaceKind(from path: NWPath) -> NetworkInterfaceKind {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.loopback) { return .other }
        return .unknown
    }
}

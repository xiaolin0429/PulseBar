import Dispatch

public protocol MemoryPressureReading: Sendable {
    /// 获取系统内存压力状态；尚未接收到可靠事件时允许返回 unknown。
    func currentPressure() async -> MemoryPressureState
}

public actor SystemMemoryPressureMonitor: MemoryPressureReading {
    private var source: DispatchSourceMemoryPressure?
    private var state: MemoryPressureState = .unknown

    /// 创建惰性压力监听器；初始化时不注册事件源。
    public init() {}

    /// 首次读取时启动事件监听，返回最近收到的压力状态；首个事件前保持 unknown。
    public func currentPressure() -> MemoryPressureState {
        startIfNeeded()
        return state
    }

    /// 取消事件源并清除缓存状态，后续读取可重新启动监听。
    public func stop() {
        source?.cancel()
        source = nil
        state = .unknown
    }

    /// 只注册一个低优先级压力事件源，用事件更新代替周期查询。
    private func startIfNeeded() {
        guard source == nil else { return }
        let newSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: DispatchQueue(label: "com.pulsebar.memory-pressure", qos: .utility)
        )
        newSource.setEventHandler { [weak self] in
            Task { await self?.consumeEvent() }
        }
        source = newSource
        newSource.resume()
    }

    /// 在 actor 内消费压力事件，多个标志并存时优先采用最严重等级。
    private func consumeEvent() {
        guard let data = source?.data else { return }
        if data.contains(.critical) {
            state = .critical
        } else if data.contains(.warning) {
            state = .warning
        } else if data.contains(.normal) {
            state = .normal
        }
    }
}

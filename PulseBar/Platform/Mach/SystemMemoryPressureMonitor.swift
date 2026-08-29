import Dispatch

public protocol MemoryPressureReading: Sendable {
    func currentPressure() async -> MemoryPressureState
}

public actor SystemMemoryPressureMonitor: MemoryPressureReading {
    private var source: DispatchSourceMemoryPressure?
    private var state: MemoryPressureState = .unknown

    public init() {}

    public func currentPressure() -> MemoryPressureState {
        startIfNeeded()
        return state
    }

    public func stop() {
        source?.cancel()
        source = nil
        state = .unknown
    }

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

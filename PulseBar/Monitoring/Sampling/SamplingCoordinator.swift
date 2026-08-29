import Foundation

public actor SamplingCoordinator {
    public typealias Delivery = @MainActor @Sendable (SystemSnapshot, DashboardHistory) -> Void

    private let cpuCollector: CPUCollector
    private let memoryCollector: MemoryCollector
    private let diskCollector: DiskCollector
    private let networkCollector: NetworkCollector
    private let clock = ContinuousClock()
    private var historyStore = HistoryStore()
    private var snapshotNormalizer = SnapshotNormalizer()
    private var refreshPolicy: RefreshPolicy = .adaptive
    private var historyWindow: HistoryWindow = .seconds60
    private var dashboardVisible = false
    private var isPaused = false
    private var isSleeping = false
    private var sequence: UInt64 = 0
    private var samplingTask: Task<Void, Never>?
    private var delivery: Delivery?

    public init(
        cpuCollector: CPUCollector = CPUCollector(),
        memoryCollector: MemoryCollector = MemoryCollector(),
        diskCollector: DiskCollector = DiskCollector(),
        networkCollector: NetworkCollector = NetworkCollector()
    ) {
        self.cpuCollector = cpuCollector
        self.memoryCollector = memoryCollector
        self.diskCollector = diskCollector
        self.networkCollector = networkCollector
    }

    public func start(delivery: @escaping Delivery) async {
        self.delivery = delivery
        guard samplingTask == nil else { return }
        await sampleOnce()
        scheduleLoop()
    }

    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        delivery = nil
    }

    public func pause() {
        isPaused = true
        samplingTask?.cancel()
        samplingTask = nil
    }

    public func resume() async {
        guard isPaused else { return }
        isPaused = false
        await resetRateBaselines()
        await sampleOnce()
        scheduleLoop()
    }

    public func prepareForSleep() {
        isSleeping = true
        samplingTask?.cancel()
        samplingTask = nil
    }

    public func resumeAfterWake() async {
        isSleeping = false
        await resetRateBaselines()
        guard !isPaused else { return }
        await sampleOnce()
        scheduleLoop()
    }

    public func setDashboardVisible(_ visible: Bool) {
        guard dashboardVisible != visible else { return }
        dashboardVisible = visible
        restartLoopIfRunning()
    }

    public func setRefreshPolicy(_ policy: RefreshPolicy) {
        guard refreshPolicy != policy else { return }
        refreshPolicy = policy
        restartLoopIfRunning()
    }

    public func setHistoryWindow(_ window: HistoryWindow) {
        historyWindow = window
    }

    public func volumeConfigurationChanged() async {
        await diskCollector.invalidateVolumes()
    }

    public func sampleNow() async {
        guard !isPaused, !isSleeping else { return }
        await sampleOnce()
    }

    private func scheduleLoop() {
        guard samplingTask == nil, !isPaused, !isSleeping else { return }
        let interval = refreshPolicy.interval(dashboardVisible: dashboardVisible)
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval, tolerance: interval / 10)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await self?.sampleOnce()
            }
        }
    }

    private func restartLoopIfRunning() {
        guard samplingTask != nil else { return }
        samplingTask?.cancel()
        samplingTask = nil
        scheduleLoop()
    }

    private func sampleOnce() async {
        let instant = clock.now
        let started = instant
        sequence &+= 1
        async let cpuValue = cpuCollector.sample()
        async let memoryValue = memoryCollector.sample()
        async let diskValue = diskCollector.sample(at: instant)
        async let networkValue = networkCollector.sample(at: instant)
        let (cpu, memory, disk, network) = await (
            cpuValue,
            memoryValue,
            diskValue,
            networkValue
        )
        let rawSnapshot = SystemSnapshot(
            sequence: sequence,
            wallTime: Date(),
            monotonicTime: instant,
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network
        )
        let snapshot = snapshotNormalizer.normalize(rawSnapshot)
        historyStore.append(snapshot)
        let history = dashboardVisible
            ? historyStore.snapshot(endingAt: instant, window: historyWindow)
            : .empty
        if let delivery {
            await delivery(snapshot, history)
        }
        let elapsed = started.duration(to: clock.now).secondsValue * 1_000
        if elapsed > 20 {
            PulseBarLog.sampling.notice("Sampling exceeded budget: \(elapsed, format: .fixed(precision: 2)) ms")
        }
    }

    private func resetRateBaselines() async {
        snapshotNormalizer.reset()
        await cpuCollector.resetBaseline()
        await diskCollector.resetBaseline()
        await networkCollector.resetBaseline()
    }
}

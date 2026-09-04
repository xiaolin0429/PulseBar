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

    /// 组装四类采集器；actor 内部统一持有历史、速率基线管理和采样任务状态。
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

    /// 登记主线程投递回调，并在尚未运行时立即采样后启动周期循环。
    public func start(delivery: @escaping Delivery) async {
        self.delivery = delivery
        guard samplingTask == nil else { return }
        await sampleOnce()
        scheduleLoop()
    }

    /// 取消周期任务并解除投递回调；不会清空已积累的历史数据。
    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        delivery = nil
    }

    /// 暂停周期采样，保留回调和历史，以便用户恢复监控。
    public func pause() {
        isPaused = true
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// 从用户暂停状态恢复：先重置差分基线，再立即采样并重新调度。
    public func resume() async {
        guard isPaused else { return }
        isPaused = false
        await resetRateBaselines()
        await sampleOnce()
        scheduleLoop()
    }

    /// 标记系统睡眠并取消周期循环，避免在睡眠期间持续调度。
    public func prepareForSleep() {
        isSleeping = true
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// 唤醒后重置速率和旧值基线；用户此前已暂停时仍保持暂停。
    public func resumeAfterWake() async {
        isSleeping = false
        await resetRateBaselines()
        guard !isPaused else { return }
        await sampleOnce()
        scheduleLoop()
    }

    /// 同步面板可见性；仅在状态变化时重设运行中的采样间隔。
    public func setDashboardVisible(_ visible: Bool) {
        guard dashboardVisible != visible else { return }
        dashboardVisible = visible
        restartLoopIfRunning()
    }

    /// 更新刷新策略并重启已有循环，使新间隔生效；不主动启动已暂停的采样。
    public func setRefreshPolicy(_ policy: RefreshPolicy) {
        guard refreshPolicy != policy else { return }
        refreshPolicy = policy
        restartLoopIfRunning()
    }

    /// 更新下次导出历史时使用的时间窗口，不改变底层环形缓存容量。
    public func setHistoryWindow(_ window: HistoryWindow) {
        historyWindow = window
    }

    /// 将挂载或卸载事件转交磁盘采集器，触发下一帧刷新卷容量。
    public func volumeConfigurationChanged() async {
        await diskCollector.invalidateVolumes()
    }

    /// 在未暂停、未睡眠时请求一次即时采样，供打开面板时刷新使用。
    public func sampleNow() async {
        guard !isPaused, !isSleeping else { return }
        await sampleOnce()
    }

    /// 创建带容差的周期任务，每次采样结束后再等待下一轮，减少无谓唤醒。
    /// 已存在任务、暂停或睡眠时不重复创建循环。
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

    /// 仅替换已存在的周期任务，避免修改设置意外恢复暂停状态。
    private func restartLoopIfRunning() {
        guard samplingTask != nil else { return }
        samplingTask?.cancel()
        samplingTask = nil
        scheduleLoop()
    }

    /// 并行读取四类指标，统一快照序号和时间戳，再归一化、存历史并投递主线程。
    /// 面板隐藏时只投递空历史，不构造绘图数组；整轮耗时超过 20 ms 时记录日志。
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

    /// 清除短期旧值缓存及 CPU、磁盘、网络差分基线，隔离暂停或睡眠前的数据。
    private func resetRateBaselines() async {
        snapshotNormalizer.reset()
        await cpuCollector.resetBaseline()
        await diskCollector.resetBaseline()
        await networkCollector.resetBaseline()
    }
}

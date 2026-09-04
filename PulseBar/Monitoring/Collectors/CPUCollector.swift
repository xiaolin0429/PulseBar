import Darwin
import Foundation

public actor CPUCollector {
    private let reader: any CPURawReading
    private let loadAverageProvider: @Sendable () -> [Double]
    private var previous: [CPUTickCounter]?

    /// 注入累计计数器和负载读取器；保留依赖注入入口，便于测试不依赖真实 CPU。
    public init(
        reader: any CPURawReading = MachCPURawReader(),
        loadAverageProvider: @escaping @Sendable () -> [Double] = CPUCollector.systemLoadAverages
    ) {
        self.reader = reader
        self.loadAverageProvider = loadAverageProvider
    }

    /// 读取各核心累计 ticks，用相邻两次差值计算整体及单核占用率。
    /// 首帧、核心数变化、计数器回退或无增量时返回预热状态，不能将累计值直接当成使用率。
    public func sample() -> MetricValue<CPUSnapshot> {
        do {
            let current = try reader.readTicks()
            guard !current.isEmpty else {
                return .unavailable(
                    MetricFailure(
                        code: .sourceMissing,
                        userMessageKey: "metric.cpu.unavailable",
                        debugContext: "No logical processors returned"
                    )
                )
            }
            guard let previous, previous.count == current.count else {
                self.previous = current
                return .warmingUp
            }

            var totalUser: UInt64 = 0
            var totalSystem: UInt64 = 0
            var totalNice: UInt64 = 0
            var totalIdle: UInt64 = 0
            var perCore: [Double] = []
            perCore.reserveCapacity(current.count)

            for (old, new) in zip(previous, current) {
                guard let user = delta(new.user, old.user),
                      let system = delta(new.system, old.system),
                      let nice = delta(new.nice, old.nice),
                      let idle = delta(new.idle, old.idle) else {
                    self.previous = current
                    return .warmingUp
                }
                let total = user + system + nice + idle
                guard total > 0 else {
                    self.previous = current
                    return .warmingUp
                }
                totalUser += user
                totalSystem += system
                totalNice += nice
                totalIdle += idle
                perCore.append(clamp(Double(user + system + nice) / Double(total)))
            }

            self.previous = current
            let aggregateTotal = totalUser + totalSystem + totalNice + totalIdle
            guard aggregateTotal > 0 else { return .warmingUp }
            let loads = loadAverageProvider()
            return .available(
                CPUSnapshot(
                    totalUsageRatio: clamp(
                        Double(totalUser + totalSystem + totalNice) / Double(aggregateTotal)
                    ),
                    userUsageRatio: clamp(Double(totalUser) / Double(aggregateTotal)),
                    systemUsageRatio: clamp(Double(totalSystem) / Double(aggregateTotal)),
                    niceUsageRatio: clamp(Double(totalNice) / Double(aggregateTotal)),
                    idleUsageRatio: clamp(Double(totalIdle) / Double(aggregateTotal)),
                    perCoreUsageRatios: perCore,
                    loadAverage1m: loads[safe: 0],
                    loadAverage5m: loads[safe: 1],
                    loadAverage15m: loads[safe: 2]
                )
            )
        } catch {
            return .unavailable(.reading(error, source: "CPU"))
        }
    }

    /// 丢弃上一次计数，下一帧重新预热，避免把暂停或睡眠时段算进速率。
    public func resetBaseline() {
        previous = nil
    }

    /// 求累计计数差；回退时返回 nil，让调用方重建基线。
    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        current >= previous ? current - previous : nil
    }

    /// 将使用率限制在 0…1；非有限值按 0 处理。
    private func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    /// 读取系统 1、5、15 分钟负载；只返回成功读取的项，失败时返回空数组。
    public static func systemLoadAverages() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        let count = getloadavg(&values, Int32(values.count))
        guard count > 0 else { return [] }
        return Array(values.prefix(Int(count)))
    }
}

private extension Collection {
    /// 仅在索引有效时读取元素，兼容系统未返回全部三个负载平均值的情况。
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

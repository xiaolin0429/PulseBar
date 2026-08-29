import Darwin
import Foundation

public actor CPUCollector {
    private let reader: any CPURawReading
    private let loadAverageProvider: @Sendable () -> [Double]
    private var previous: [CPUTickCounter]?

    public init(
        reader: any CPURawReading = MachCPURawReader(),
        loadAverageProvider: @escaping @Sendable () -> [Double] = CPUCollector.systemLoadAverages
    ) {
        self.reader = reader
        self.loadAverageProvider = loadAverageProvider
    }

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

    public func resetBaseline() {
        previous = nil
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        current >= previous ? current - previous : nil
    }

    private func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    public static func systemLoadAverages() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        let count = getloadavg(&values, Int32(values.count))
        guard count > 0 else { return [] }
        return Array(values.prefix(Int(count)))
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

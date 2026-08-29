import Foundation

public actor MemoryCollector {
    private let reader: any MemoryRawReading
    private let pressureReader: any MemoryPressureReading
    private let physicalMemoryProvider: @Sendable () -> UInt64

    public init(
        reader: any MemoryRawReading = MachMemoryRawReader(),
        pressureReader: any MemoryPressureReading = SystemMemoryPressureMonitor(),
        physicalMemoryProvider: @escaping @Sendable () -> UInt64 = {
            ProcessInfo.processInfo.physicalMemory
        }
    ) {
        self.reader = reader
        self.pressureReader = pressureReader
        self.physicalMemoryProvider = physicalMemoryProvider
    }

    public func sample() async -> MetricValue<MemorySnapshot> {
        do {
            let raw = try reader.readVMStatistics()
            let total = physicalMemoryProvider()
            guard total > 0 else {
                return .unavailable(
                    MetricFailure(
                        code: .invalidCounter,
                        userMessageKey: "metric.memory.unavailable",
                        debugContext: "Physical memory is zero"
                    )
                )
            }

            guard let free = Self.bytes(pages: raw.freePages, pageSize: raw.pageSize),
                  let active = Self.bytes(pages: raw.activePages, pageSize: raw.pageSize),
                  let inactive = Self.bytes(pages: raw.inactivePages, pageSize: raw.pageSize),
                  let speculative = Self.bytes(pages: raw.speculativePages, pageSize: raw.pageSize),
                  let wired = Self.bytes(pages: raw.wiredPages, pageSize: raw.pageSize),
                  let compressed = Self.bytes(pages: raw.compressedPages, pageSize: raw.pageSize),
                  let purgeable = Self.bytes(pages: raw.purgeablePages, pageSize: raw.pageSize) else {
                return .unavailable(
                    MetricFailure(
                        code: .invalidCounter,
                        userMessageKey: "metric.memory.unavailable",
                        debugContext: "Page count conversion overflow"
                    )
                )
            }

            let available = min(
                total,
                saturatingSum([free, inactive, speculative, purgeable])
            )
            let swap: RawSwapUsage?
            do {
                swap = try reader.readSwapUsage()
            } catch {
                swap = nil
            }
            let pressure = await pressureReader.currentPressure()
            return .available(
                MemorySnapshot(
                    physicalTotalBytes: total,
                    usedApproximationBytes: total - available,
                    availableApproximationBytes: available,
                    freeBytes: free,
                    activeBytes: active,
                    inactiveBytes: inactive,
                    speculativeBytes: speculative,
                    wiredBytes: wired,
                    compressedBytes: compressed,
                    purgeableBytes: purgeable,
                    swapUsedBytes: swap?.usedBytes,
                    swapTotalBytes: swap?.totalBytes,
                    pressure: pressure
                )
            )
        } catch {
            return .unavailable(.reading(error, source: "Memory"))
        }
    }

    static func bytes(pages: UInt64, pageSize: UInt64) -> UInt64? {
        let result = pages.multipliedReportingOverflow(by: pageSize)
        return result.overflow ? nil : result.partialValue
    }

    private func saturatingSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partial, value in
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? UInt64.max : result.partialValue
        }
    }
}

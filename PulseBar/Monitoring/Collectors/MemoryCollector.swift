import Foundation

public actor MemoryCollector {
    private let reader: any MemoryRawReading
    private let pressureReader: any MemoryPressureReading
    private let physicalMemoryProvider: @Sendable () -> UInt64

    /// 注入 VM、压力状态和物理内存来源，便于独立验证内存口径与异常数据。
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

    /// 将 VM 页数转为字节，以空闲、非活跃、推测和可清除内存近似估算可用量。
    /// 可用量不超过物理总量；交换空间失败只隐藏该字段，VM 读取或页数转换失败则整项不可用。
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

    /// 将页数乘以当前系统页大小；发生整数溢出时返回 nil，而不是产生错误容量。
    static func bytes(pages: UInt64, pageSize: UInt64) -> UInt64? {
        let result = pages.multipliedReportingOverflow(by: pageSize)
        return result.overflow ? nil : result.partialValue
    }

    /// 以饱和加法累计字节数，溢出时返回 UInt64.max，后续再按物理总量截断。
    private func saturatingSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partial, value in
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? UInt64.max : result.partialValue
        }
    }
}

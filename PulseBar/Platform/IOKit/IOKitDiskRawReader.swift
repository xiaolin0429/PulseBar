import Foundation
import IOKit
import IOKit.storage

public struct IOKitDiskRawReader: DiskRawReading {
    /// 创建无状态块设备读取器；IOKit 句柄只在单次读取内持有。
    public init() {}

    /// 遍历块存储驱动统计，用注册表 ID 标识设备；缺失字段的设备被跳过。
    /// 迭代器和服务句柄均在本次调用内释放；没有有效计数时抛出来源不可用错误。
    public func readDeviceCounters() throws -> [DiskDeviceCounter] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching(kIOBlockStorageDriverClass)
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw SystemMetricReadError.systemCall(function: "IOServiceGetMatchingServices", code: result)
        }
        defer { IOObjectRelease(iterator) }

        var counters: [DiskDeviceCounter] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let property = IORegistryEntryCreateCFProperty(
                service,
                kIOBlockStorageDriverStatisticsKey as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue(),
            let statistics = property as? [String: Any],
            let readBytes = uint64(
                statistics[kIOBlockStorageDriverStatisticsBytesReadKey as String]
            ),
            let writtenBytes = uint64(
                statistics[kIOBlockStorageDriverStatisticsBytesWrittenKey as String]
            ) else {
                continue
            }

            var registryID: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else {
                continue
            }
            counters.append(
                DiskDeviceCounter(id: registryID, readBytes: readBytes, writtenBytes: writtenBytes)
            )
        }

        guard !counters.isEmpty else {
            throw SystemMetricReadError.sourceUnavailable("IOBlockStorageDriver statistics")
        }
        return counters.sorted { $0.id < $1.id }
    }

    /// 兼容 IOKit 字典中的 NSNumber 与 UInt64 表示；其他类型返回 nil。
    private func uint64(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        return value as? UInt64
    }
}

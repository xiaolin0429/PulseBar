import Darwin
import Foundation

public struct VolumeCapacityRawReader: VolumeRawReading {
    /// 创建无状态卷容量读取器；枚举由采集器按低频策略触发。
    public init() {}

    /// 枚举非隐藏挂载卷，过滤明确非本地或容量无效的条目，根卷优先排序。
    /// 单个卷读取失败时跳过该卷，整个挂载卷列表不可获取时抛出错误。
    public func readVolumes() throws -> [RawVolumeCapacity] {
        let keys: Set<URLResourceKey> = [
            .volumeIdentifierKey,
            .volumeNameKey,
            .volumeIsLocalKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) else {
            throw SystemMetricReadError.sourceUnavailable("mounted volumes")
        }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.volumeIsLocal != false,
                  let capacity = capacity(for: url) else {
                return nil
            }

            let identifier = values.volumeIdentifier.map(String.init(describing:)) ?? url.path
            return RawVolumeCapacity(
                id: identifier,
                name: values.volumeName ?? url.lastPathComponent,
                mountPath: url.path,
                totalBytes: capacity.total,
                availableBytes: capacity.available,
                isLocal: values.volumeIsLocal,
                isInternal: values.volumeIsInternal,
                isRemovable: values.volumeIsRemovable
            )
        }
        .sorted { left, right in
            if left.mountPath == "/" { return true }
            if right.mountPath == "/" { return false }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    /// 通过 statfs 的普通可用块数计算字节容量，不触发可清除空间估算。
    /// 拒绝失败、零总量和乘法溢出，并将可用量限制在总容量内。
    private func capacity(for url: URL) -> (total: UInt64, available: UInt64)? {
        var statistics = statfs()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return statfs(path, &statistics)
        }
        guard result == 0 else { return nil }

        let blockSize = UInt64(statistics.f_bsize)
        let total = UInt64(statistics.f_blocks).multipliedReportingOverflow(by: blockSize)
        let available = UInt64(statistics.f_bavail).multipliedReportingOverflow(by: blockSize)
        guard !total.overflow, total.partialValue > 0, !available.overflow else { return nil }
        return (
            total: total.partialValue,
            available: min(available.partialValue, total.partialValue)
        )
    }
}

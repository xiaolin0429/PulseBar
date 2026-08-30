import Darwin
import Foundation

public struct VolumeCapacityRawReader: VolumeRawReading {
    public init() {}

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

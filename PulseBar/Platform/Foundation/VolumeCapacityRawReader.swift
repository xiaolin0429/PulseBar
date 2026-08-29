import Foundation

public struct VolumeCapacityRawReader: VolumeRawReading {
    public init() {}

    public func readVolumes() throws -> [RawVolumeCapacity] {
        let keys: Set<URLResourceKey> = [
            .volumeIdentifierKey,
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
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
                  let total = values.volumeTotalCapacity,
                  total > 0 else {
                return nil
            }

            let important = values.volumeAvailableCapacityForImportantUsage
            let fallback = values.volumeAvailableCapacity.map(Int64.init)
            let available = max(0, important ?? fallback ?? 0)
            let identifier = values.volumeIdentifier.map(String.init(describing:)) ?? url.path
            return RawVolumeCapacity(
                id: identifier,
                name: values.volumeName ?? url.lastPathComponent,
                mountPath: url.path,
                totalBytes: UInt64(total),
                availableBytes: UInt64(available),
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
}

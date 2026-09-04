import Foundation

public struct CPUTickCounter: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let nice: UInt64
    public let idle: UInt64

    public init(user: UInt64, system: UInt64, nice: UInt64, idle: UInt64) {
        self.user = user
        self.system = system
        self.nice = nice
        self.idle = idle
    }
}

public struct RawVMStatistics: Sendable, Equatable {
    public let pageSize: UInt64
    public let freePages: UInt64
    public let activePages: UInt64
    public let inactivePages: UInt64
    public let speculativePages: UInt64
    public let wiredPages: UInt64
    public let compressedPages: UInt64
    public let purgeablePages: UInt64

    public init(
        pageSize: UInt64,
        freePages: UInt64,
        activePages: UInt64,
        inactivePages: UInt64,
        speculativePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        purgeablePages: UInt64
    ) {
        self.pageSize = pageSize
        self.freePages = freePages
        self.activePages = activePages
        self.inactivePages = inactivePages
        self.speculativePages = speculativePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
        self.purgeablePages = purgeablePages
    }
}

public struct RawSwapUsage: Sendable, Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64

    public init(totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
    }
}

public struct DiskDeviceCounter: Sendable, Equatable, Identifiable {
    public let id: UInt64
    public let readBytes: UInt64
    public let writtenBytes: UInt64

    public init(id: UInt64, readBytes: UInt64, writtenBytes: UInt64) {
        self.id = id
        self.readBytes = readBytes
        self.writtenBytes = writtenBytes
    }
}

public struct RawVolumeCapacity: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let mountPath: String
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public let isLocal: Bool?
    public let isInternal: Bool?
    public let isRemovable: Bool?

    public init(
        id: String,
        name: String,
        mountPath: String,
        totalBytes: UInt64,
        availableBytes: UInt64,
        isLocal: Bool?,
        isInternal: Bool?,
        isRemovable: Bool?
    ) {
        self.id = id
        self.name = name
        self.mountPath = mountPath
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.isLocal = isLocal
        self.isInternal = isInternal
        self.isRemovable = isRemovable
    }
}

public struct InterfaceCounter: Sendable, Equatable, Identifiable {
    public let name: String
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let isUp: Bool
    public let isRunning: Bool
    public let isLoopback: Bool

    public var id: String { name }

    public init(
        name: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        isUp: Bool,
        isRunning: Bool,
        isLoopback: Bool
    ) {
        self.name = name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.isUp = isUp
        self.isRunning = isRunning
        self.isLoopback = isLoopback
    }
}

public enum SystemMetricReadError: Error, Sendable, Equatable, CustomStringConvertible {
    case systemCall(function: String, code: Int32)
    case malformedData(source: String)
    case sourceUnavailable(String)

    public var description: String {
        switch self {
        case let .systemCall(function, code):
            return "\(function) failed (\(code))"
        case let .malformedData(source):
            return "Malformed data from \(source)"
        case let .sourceUnavailable(source):
            return "Source unavailable: \(source)"
        }
    }
}

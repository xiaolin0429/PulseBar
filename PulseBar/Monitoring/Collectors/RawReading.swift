public protocol CPURawReading: Sendable {
    func readTicks() throws -> [CPUTickCounter]
}

public protocol MemoryRawReading: Sendable {
    func readVMStatistics() throws -> RawVMStatistics
    func readSwapUsage() throws -> RawSwapUsage?
}

public protocol DiskRawReading: Sendable {
    func readDeviceCounters() throws -> [DiskDeviceCounter]
}

public protocol VolumeRawReading: Sendable {
    func readVolumes() throws -> [RawVolumeCapacity]
}

public protocol NetworkRawReading: Sendable {
    func readInterfaceCounters() throws -> [InterfaceCounter]
}

public protocol PrimaryInterfaceResolving: Sendable {
    func primaryInterfaceName() -> String?
}

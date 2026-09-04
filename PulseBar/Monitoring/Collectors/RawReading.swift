public protocol CPURawReading: Sendable {
    /// 读取每个逻辑核心的累计 ticks；由采集器负责跨帧差分，底层错误向上抛出。
    func readTicks() throws -> [CPUTickCounter]
}

public protocol MemoryRawReading: Sendable {
    /// 读取 VM 页计数及页大小，保持原始单位，不在读取层计算占用率。
    func readVMStatistics() throws -> RawVMStatistics
    /// 读取交换空间字节数；不支持时可返回 nil，读取失败可抛出错误。
    func readSwapUsage() throws -> RawSwapUsage?
}

public protocol DiskRawReading: Sendable {
    /// 读取各块设备的累计读写字节数，并提供稳定设备 ID 供跨帧匹配。
    func readDeviceCounters() throws -> [DiskDeviceCounter]
}

public protocol VolumeRawReading: Sendable {
    /// 枚举可展示的本地卷容量；高开销刷新频率由采集器控制。
    func readVolumes() throws -> [RawVolumeCapacity]
}

public protocol NetworkRawReading: Sendable {
    /// 读取各接口累计收发字节数与链路标志，不在读取层选择主接口。
    func readInterfaceCounters() throws -> [InterfaceCounter]
}

public protocol PrimaryInterfaceResolving: Sendable {
    /// 返回当前系统主接口名；无法确定时返回 nil，允许采集器回退选择。
    func primaryInterfaceName() -> String?
}

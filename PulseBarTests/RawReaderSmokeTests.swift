import XCTest
@testable import PulseBarCore

final class RawReaderSmokeTests: XCTestCase {
    /// 在真实机器读取 Mach CPU 计数，确认至少存在一个逻辑处理器。
    func testMachCPUReaderReturnsLogicalProcessors() throws {
        let counters = try MachCPURawReader().readTicks()
        XCTAssertFalse(counters.isEmpty)
    }

    /// 在真实机器读取 VM 统计，确认页大小和活动页数据有效。
    func testMemoryReaderReturnsUsablePageSize() throws {
        let statistics = try MachMemoryRawReader().readVMStatistics()
        XCTAssertGreaterThan(statistics.pageSize, 0)
        XCTAssertGreaterThan(statistics.activePages + statistics.inactivePages, 0)
    }

    /// 检查真实接口枚举结果按名称去重；此断言不要求接口列表非空。
    func testNetworkReaderDoesNotDuplicateNames() throws {
        let counters = try BSDInterfaceCounterReader().readInterfaceCounters()
        XCTAssertEqual(Set(counters.map(\.name)).count, counters.count)
    }

    /// 检查真实本地卷枚举非空，且各卷总容量均大于零。
    func testVolumeReaderReturnsOnlyValidCapacities() throws {
        let volumes = try VolumeCapacityRawReader().readVolumes()
        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.allSatisfy { $0.totalBytes > 0 })
    }
}

import XCTest
@testable import PulseBarCore

final class RawReaderSmokeTests: XCTestCase {
    func testMachCPUReaderReturnsLogicalProcessors() throws {
        let counters = try MachCPURawReader().readTicks()
        XCTAssertFalse(counters.isEmpty)
    }

    func testMemoryReaderReturnsUsablePageSize() throws {
        let statistics = try MachMemoryRawReader().readVMStatistics()
        XCTAssertGreaterThan(statistics.pageSize, 0)
        XCTAssertGreaterThan(statistics.activePages + statistics.inactivePages, 0)
    }

    func testNetworkReaderDoesNotDuplicateNames() throws {
        let counters = try BSDInterfaceCounterReader().readInterfaceCounters()
        XCTAssertEqual(Set(counters.map(\.name)).count, counters.count)
    }

    func testVolumeReaderReturnsOnlyValidCapacities() throws {
        let volumes = try VolumeCapacityRawReader().readVolumes()
        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.allSatisfy { $0.totalBytes > 0 })
    }
}

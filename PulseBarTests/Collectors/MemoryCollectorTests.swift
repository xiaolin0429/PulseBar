import XCTest
@testable import PulseBarCore

final class MemoryCollectorTests: XCTestCase {
    /// 验证估算可用内存超过物理总量时被截断，并保留拆分、交换空间与压力信息。
    func testMemoryFormulaClampsAvailableToPhysicalTotal() async {
        let raw = RawVMStatistics(
            pageSize: 4,
            freePages: 10,
            activePages: 20,
            inactivePages: 20,
            speculativePages: 5,
            wiredPages: 10,
            compressedPages: 3,
            purgeablePages: 5
        )
        let collector = MemoryCollector(
            reader: FixedMemoryReader(
                statistics: raw,
                swap: RawSwapUsage(totalBytes: 200, usedBytes: 50, freeBytes: 150)
            ),
            pressureReader: FixedPressureReader(pressure: .warning),
            physicalMemoryProvider: { 100 }
        )

        guard case let .available(value) = await collector.sample() else {
            return XCTFail("Expected available memory snapshot")
        }
        XCTAssertEqual(value.availableApproximationBytes, 100)
        XCTAssertEqual(value.usedApproximationBytes, 0)
        XCTAssertEqual(value.activeBytes, 80)
        XCTAssertEqual(value.swapUsedBytes, 50)
        XCTAssertEqual(value.pressure, .warning)
    }

    /// 验证页数换算同时处理有效结果和乘法溢出。
    func testPageConversionRejectsOverflow() {
        XCTAssertNil(MemoryCollector.bytes(pages: .max, pageSize: 2))
        XCTAssertEqual(MemoryCollector.bytes(pages: 4, pageSize: 16_384), 65_536)
    }
}

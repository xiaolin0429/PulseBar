import XCTest
@testable import PulseBarCore

final class CPUCollectorTests: XCTestCase {
    func testFirstSampleWarmsAndSecondUsesAggregateTicks() async {
        let reader = SequenceCPUReader([
            [tick(100, 50, 0, 850), tick(200, 50, 0, 750)],
            [tick(150, 70, 0, 880), tick(210, 60, 0, 830)]
        ])
        let collector = CPUCollector(reader: reader, loadAverageProvider: { [1, 2, 3] })

        let first = await collector.sample()
        XCTAssertEqual(first, .warmingUp)
        guard case let .available(value) = await collector.sample() else {
            return XCTFail("Expected available CPU snapshot")
        }

        XCTAssertEqual(value.totalUsageRatio, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(value.perCoreUsageRatios, [0.7, 0.2])
        XCTAssertEqual(value.loadAverage15m, 3)
    }

    func testCounterRollbackRebuildsBaseline() async {
        let reader = SequenceCPUReader([
            [tick(100, 0, 0, 100)],
            [tick(90, 0, 0, 110)]
        ])
        let collector = CPUCollector(reader: reader, loadAverageProvider: { [] })

        let first = await collector.sample()
        let second = await collector.sample()
        XCTAssertEqual(first, .warmingUp)
        XCTAssertEqual(second, .warmingUp)
    }

    func testCoreCountChangeRebuildsBaseline() async {
        let reader = SequenceCPUReader([
            [tick(1, 1, 0, 8)],
            [tick(2, 2, 0, 16), tick(1, 1, 0, 8)]
        ])
        let collector = CPUCollector(reader: reader, loadAverageProvider: { [] })

        let first = await collector.sample()
        let second = await collector.sample()
        XCTAssertEqual(first, .warmingUp)
        XCTAssertEqual(second, .warmingUp)
    }
}

import XCTest
@testable import PulseBarCore

final class DiskCollectorTests: XCTestCase {
    func testDiskRatesUseRealElapsedTimeAndAggregateDevices() async {
        let reader = SequenceDiskReader([
            [
                DiskDeviceCounter(id: 1, readBytes: 100, writtenBytes: 200),
                DiskDeviceCounter(id: 2, readBytes: 50, writtenBytes: 50)
            ],
            [
                DiskDeviceCounter(id: 1, readBytes: 300, writtenBytes: 500),
                DiskDeviceCounter(id: 2, readBytes: 150, writtenBytes: 150)
            ]
        ])
        let collector = DiskCollector(
            counterReader: reader,
            volumeReader: FixedVolumeReader(volumes: [testVolume])
        )
        let start = ContinuousClock().now

        guard case let .available(first) = await collector.sample(at: start) else {
            return XCTFail("Expected disk capacity during warmup")
        }
        XCTAssertEqual(first.ioState, .warmingUp)

        guard case let .available(second) = await collector.sample(
            at: start.advanced(by: .seconds(2))
        ) else {
            return XCTFail("Expected available disk snapshot")
        }
        XCTAssertEqual(second.aggregateReadBytesPerSecond, 150)
        XCTAssertEqual(second.aggregateWriteBytesPerSecond, 200)
        XCTAssertEqual(second.primaryVolume?.availableCapacityBytes, 400)
    }

    func testDiskIOFailureDoesNotHideCapacity() async {
        let collector = DiskCollector(
            counterReader: FailingDiskReader(),
            volumeReader: FixedVolumeReader(volumes: [testVolume])
        )
        guard case let .available(snapshot) = await collector.sample(at: ContinuousClock().now) else {
            return XCTFail("Expected capacity-only degradation")
        }
        guard case .unavailable = snapshot.ioState else {
            return XCTFail("Expected unavailable I/O state")
        }
        XCTAssertEqual(snapshot.volumes.count, 1)
    }

    func testCounterRollbackWarmsInsteadOfProducingNegativeRate() async {
        let reader = SequenceDiskReader([
            [DiskDeviceCounter(id: 1, readBytes: 200, writtenBytes: 200)],
            [DiskDeviceCounter(id: 1, readBytes: 100, writtenBytes: 300)]
        ])
        let collector = DiskCollector(
            counterReader: reader,
            volumeReader: FixedVolumeReader(volumes: [testVolume])
        )
        let start = ContinuousClock().now
        _ = await collector.sample(at: start)
        guard case let .available(snapshot) = await collector.sample(
            at: start.advanced(by: .seconds(1))
        ) else { return XCTFail("Expected disk snapshot") }
        XCTAssertEqual(snapshot.ioState, .warmingUp)
    }
}

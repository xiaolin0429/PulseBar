import Foundation
import XCTest
@testable import PulseBarCore

final class SamplingCoordinatorTests: XCTestCase {
    func testCoordinatorPublishesSequentialSnapshotsAndVisibleHistory() async {
        let cpu = CPUCollector(
            reader: SequenceCPUReader([
                [tick(100, 0, 0, 900)],
                [tick(150, 0, 0, 950)]
            ]),
            loadAverageProvider: { [] }
        )
        let memory = MemoryCollector(
            reader: FixedMemoryReader(
                statistics: RawVMStatistics(
                    pageSize: 1,
                    freePages: 10,
                    activePages: 70,
                    inactivePages: 10,
                    speculativePages: 0,
                    wiredPages: 10,
                    compressedPages: 0,
                    purgeablePages: 0
                ),
                swap: nil
            ),
            pressureReader: FixedPressureReader(pressure: .normal),
            physicalMemoryProvider: { 100 }
        )
        let disk = DiskCollector(
            counterReader: SequenceDiskReader([
                [DiskDeviceCounter(id: 1, readBytes: 100, writtenBytes: 100)],
                [DiskDeviceCounter(id: 1, readBytes: 200, writtenBytes: 300)]
            ]),
            volumeReader: FixedVolumeReader(volumes: [testVolume])
        )
        let network = NetworkCollector(
            counterReader: SequenceNetworkReader([
                [interface("en0", received: 100, sent: 100)],
                [interface("en0", received: 200, sent: 300)]
            ]),
            interfaceResolver: FixedInterfaceResolver(name: "en0"),
            pathReader: FixedPathReader(
                path: NetworkPathState(status: .online, interfaceKind: .wifi)
            )
        )
        let coordinator = SamplingCoordinator(
            cpuCollector: cpu,
            memoryCollector: memory,
            diskCollector: disk,
            networkCollector: network
        )
        let recorder = await MainActor.run { DeliveryRecorder() }
        await coordinator.setDashboardVisible(true)
        await coordinator.start { snapshot, history in
            recorder.record(snapshot: snapshot, history: history)
        }
        await coordinator.sampleNow()
        await coordinator.stop()

        let result = await MainActor.run { recorder.result }
        XCTAssertEqual(result.snapshots.map(\.sequence), [1, 2])
        XCTAssertEqual(result.histories.last?.cpuUsage.count, 1)
        XCTAssertEqual(result.histories.last?.memoryUsage.count, 2)
    }
}

@MainActor
private final class DeliveryRecorder {
    private var snapshots: [SystemSnapshot] = []
    private var histories: [DashboardHistory] = []

    var result: (snapshots: [SystemSnapshot], histories: [DashboardHistory]) {
        (snapshots, histories)
    }

    func record(snapshot: SystemSnapshot, history: DashboardHistory) {
        snapshots.append(snapshot)
        histories.append(history)
    }
}

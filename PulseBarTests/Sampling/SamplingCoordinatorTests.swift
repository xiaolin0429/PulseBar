import Foundation
import XCTest
@testable import PulseBarCore

final class SamplingCoordinatorTests: XCTestCase {
    /// 验证协调器连续投递递增序号，并在面板可见时包含有效历史点。
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

    /// 验证面板隐藏时仍投递快照，但历史始终为空，避免后台构造展示数组。
    func testHiddenDashboardDoesNotMaterializeHistory() async {
        let coordinator = makeCoordinator()
        let recorder = await MainActor.run { DeliveryRecorder() }
        await coordinator.start { snapshot, history in
            recorder.record(snapshot: snapshot, history: history)
        }
        await coordinator.sampleNow()
        await coordinator.stop()

        let result = await MainActor.run { recorder.result }
        XCTAssertEqual(result.snapshots.map(\.sequence), [1, 2])
        XCTAssertEqual(result.histories, [.empty, .empty])
    }
}

/// 组装全部使用测试读取器的协调器，避免采样调度测试依赖真实机器状态。
private func makeCoordinator() -> SamplingCoordinator {
    SamplingCoordinator(
        cpuCollector: CPUCollector(
            reader: SequenceCPUReader([
                [tick(100, 0, 0, 900)],
                [tick(150, 0, 0, 950)]
            ]),
            loadAverageProvider: { [] }
        ),
        memoryCollector: MemoryCollector(
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
        ),
        diskCollector: DiskCollector(
            counterReader: SequenceDiskReader([
                [DiskDeviceCounter(id: 1, readBytes: 100, writtenBytes: 100)],
                [DiskDeviceCounter(id: 1, readBytes: 200, writtenBytes: 300)]
            ]),
            volumeReader: FixedVolumeReader(volumes: [testVolume])
        ),
        networkCollector: NetworkCollector(
            counterReader: SequenceNetworkReader([
                [interface("en0", received: 100, sent: 100)],
                [interface("en0", received: 200, sent: 300)]
            ]),
            interfaceResolver: FixedInterfaceResolver(name: "en0"),
            pathReader: FixedPathReader(
                path: NetworkPathState(status: .online, interfaceKind: .wifi)
            )
        )
    )
}

@MainActor
private final class DeliveryRecorder {
    private var snapshots: [SystemSnapshot] = []
    private var histories: [DashboardHistory] = []

    var result: (snapshots: [SystemSnapshot], histories: [DashboardHistory]) {
        (snapshots, histories)
    }

    /// 在主线程记录每次投递的快照与历史，用于断言顺序和显示策略。
    func record(snapshot: SystemSnapshot, history: DashboardHistory) {
        snapshots.append(snapshot)
        histories.append(history)
    }
}

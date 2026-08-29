import Foundation
import XCTest
@testable import PulseBarCore

final class HistoryStoreTests: XCTestCase {
    func testRingBufferOverwritesOldestAndPreservesOrder() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        XCTAssertEqual(buffer.elements(), [2, 3, 4])
    }

    func testHistoryUsesMonotonicWindow() {
        let clock = ContinuousClock()
        let start = clock.now
        var store = HistoryStore()
        store.append(snapshot(sequence: 1, instant: start, cpu: 0.1))
        store.append(snapshot(sequence: 2, instant: start.advanced(by: .seconds(50)), cpu: 0.2))
        store.append(snapshot(sequence: 3, instant: start.advanced(by: .seconds(70)), cpu: 0.3))

        let history = store.snapshot(
            endingAt: start.advanced(by: .seconds(70)),
            window: .seconds60
        )
        XCTAssertEqual(history.cpuUsage.map(\.sequence), [2, 3])
    }

    private func snapshot(
        sequence: UInt64,
        instant: ContinuousClock.Instant,
        cpu: Double
    ) -> SystemSnapshot {
        SystemSnapshot(
            sequence: sequence,
            wallTime: Date(),
            monotonicTime: instant,
            cpu: .available(
                CPUSnapshot(
                    totalUsageRatio: cpu,
                    userUsageRatio: cpu,
                    systemUsageRatio: 0,
                    niceUsageRatio: 0,
                    idleUsageRatio: 1 - cpu,
                    perCoreUsageRatios: [cpu],
                    loadAverage1m: nil,
                    loadAverage5m: nil,
                    loadAverage15m: nil
                )
            ),
            memory: .warmingUp,
            disk: .warmingUp,
            network: .warmingUp
        )
    }
}

import Foundation
import XCTest
@testable import PulseBarCore

final class SnapshotNormalizerTests: XCTestCase {
    func testUnavailableMetricUsesRecentValueAsStaleThenExpires() {
        let clock = ContinuousClock()
        let start = clock.now
        var normalizer = SnapshotNormalizer()
        _ = normalizer.normalize(snapshot(at: start, cpu: .available(cpu(0.5))))

        let recent = normalizer.normalize(
            snapshot(
                at: start.advanced(by: .seconds(5)),
                cpu: .unavailable(failure)
            )
        )
        guard case let .stale(value, age) = recent.cpu else {
            return XCTFail("Expected recent CPU value to become stale")
        }
        XCTAssertEqual(value.totalUsageRatio, 0.5)
        XCTAssertEqual(age, .seconds(5))

        let expired = normalizer.normalize(
            snapshot(
                at: start.advanced(by: .seconds(31)),
                cpu: .unavailable(failure)
            )
        )
        guard case .unavailable = expired.cpu else {
            return XCTFail("Expected stale value to expire")
        }
    }

    func testResetDiscardsPreSleepValues() {
        let start = ContinuousClock().now
        var normalizer = SnapshotNormalizer()
        _ = normalizer.normalize(snapshot(at: start, cpu: .available(cpu(0.5))))
        normalizer.reset()
        let result = normalizer.normalize(
            snapshot(at: start.advanced(by: .seconds(1)), cpu: .unavailable(failure))
        )
        guard case .unavailable = result.cpu else {
            return XCTFail("Expected reset normalizer to discard cached values")
        }
    }

    private var failure: MetricFailure {
        MetricFailure(code: .systemCallFailed, userMessageKey: "test")
    }

    private func cpu(_ usage: Double) -> CPUSnapshot {
        CPUSnapshot(
            totalUsageRatio: usage,
            userUsageRatio: usage,
            systemUsageRatio: 0,
            niceUsageRatio: 0,
            idleUsageRatio: 1 - usage,
            perCoreUsageRatios: [usage],
            loadAverage1m: nil,
            loadAverage5m: nil,
            loadAverage15m: nil
        )
    }

    private func snapshot(
        at instant: ContinuousClock.Instant,
        cpu: MetricValue<CPUSnapshot>
    ) -> SystemSnapshot {
        SystemSnapshot(
            sequence: 1,
            wallTime: Date(),
            monotonicTime: instant,
            cpu: cpu,
            memory: .warmingUp,
            disk: .warmingUp,
            network: .warmingUp
        )
    }
}

import Foundation
import XCTest
@testable import PulseBarCore

final class SnapshotNormalizerTests: XCTestCase {
    /// 验证读取失败时近期值降级为 stale，超过 30 秒后回到不可用状态。
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

    /// 验证重置后不会继续使用睡眠前的成功值兜底。
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

    /// 构造指定占用率的单核 CPU 快照，隔离归一化逻辑与真实采样。
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

    /// 构造指定单调时间和 CPU 状态的系统快照，其他指标保持预热。
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

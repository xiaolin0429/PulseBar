import XCTest
@testable import PulseBarCore

final class MetricFormatterTests: XCTestCase {
    func testCompactRateUsesShortStableUnits() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(0), "0B/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(999), "999B/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(1_000), "1K/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(16_000), "16K/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(1_500_000), "1.5M/s")
    }

    func testCompactRateHonorsBinaryUnits() {
        XCTAssertEqual(
            MetricFormatter.compactBytesPerSecond(1_024, unitSystem: .binary),
            "1K/s"
        )
    }

    func testCompactDiskCapacityUsesShortUnits() {
        XCTAssertEqual(
            MetricFormatter.compactBytes(42 * 1_024 * 1_024 * 1_024),
            "42G"
        )
    }

    func testCompactRateRejectsInvalidValues() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(-1), "—")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(.infinity), "—")
    }

    func testCompactRateBoundsExtremeFiniteValues() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(.greatestFiniteMagnitude), "999P+/s")
    }

    func testTwoLineLabelKeepsEveryModuleInOneIntrinsicTextBlock() {
        let label = MetricFormatter.twoLineLabel(
            columns: [
                .init(top: "62%", bottom: "MEM"),
                .init(top: "↑128K/s", bottom: "↓1.8M/s"),
                .init(top: "18%", bottom: "CPU")
            ]
        )

        XCTAssertEqual(label, "62% ↑128K/s 18%\nMEM ↓1.8M/s CPU")
        let lines = label.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, lines[1].count)
    }

    func testTwoLineLabelCentersShortValuesWithinTheirColumns() {
        XCTAssertEqual(
            MetricFormatter.twoLineLabel(
                columns: [
                    .init(top: "7%", bottom: "CPU"),
                    .init(top: "—", bottom: "MEM")
                ],
                spacing: 2
            ),
            "7%    — \nCPU  MEM"
        )
    }
}

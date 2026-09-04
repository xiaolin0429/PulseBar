import XCTest
@testable import PulseBarCore

final class MetricFormatterTests: XCTestCase {
    /// 验证菜单栏速率在零值及跨量级时使用稳定的 B/K/M 短单位。
    func testCompactRateUsesShortStableUnits() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(0), "0B/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(999), "999B/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(1_000), "1K/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(16_000), "16K/s")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(1_500_000), "1.5M/s")
    }

    /// 验证选择二进制时以 1024 字节进位到 K。
    func testCompactRateHonorsBinaryUnits() {
        XCTAssertEqual(
            MetricFormatter.compactBytesPerSecond(1_024, unitSystem: .binary),
            "1K/s"
        )
    }

    /// 验证默认磁盘容量使用二进制基数和紧凑单位。
    func testCompactDiskCapacityUsesShortUnits() {
        XCTAssertEqual(
            MetricFormatter.compactBytes(42 * 1_024 * 1_024 * 1_024),
            "42G"
        )
    }

    /// 验证负速率与无穷大显示占位符，不参与数值格式化。
    func testCompactRateRejectsInvalidValues() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(-1), "—")
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(.infinity), "—")
    }

    /// 验证极大有限速率封顶为有限宽度文本，避免菜单栏标签无限变长。
    func testCompactRateBoundsExtremeFiniteValues() {
        XCTAssertEqual(MetricFormatter.compactBytesPerSecond(.greatestFiniteMagnitude), "999P+/s")
    }

    /// 验证所有模块合成一个双行文本块，且上下两行字符数一致。
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

    /// 验证较短值在列内补齐，并保留指定列间距。
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

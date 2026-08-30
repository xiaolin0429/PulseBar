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
}

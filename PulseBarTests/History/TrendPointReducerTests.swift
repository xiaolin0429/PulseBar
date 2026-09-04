import Foundation
import XCTest
@testable import PulseBarCore

final class TrendPointReducerTests: XCTestCase {
    func testReturnsInputWhenAlreadyWithinLimit() {
        let input = points(values: [0.1, 0.2, 0.3])

        XCTAssertEqual(TrendPointReducer.reduce(input, maximumCount: 3), input)
    }

    func testHandlesSingleAndTwoPointLimits() {
        let input = points(values: [0.1, 0.2, 0.3, 0.4])

        XCTAssertEqual(
            TrendPointReducer.reduce(input, maximumCount: 1).map(\.sequence),
            [4]
        )
        XCTAssertEqual(
            TrendPointReducer.reduce(input, maximumCount: 2).map(\.sequence),
            [1, 4]
        )
    }

    func testPreservesEndpointsAndBucketExtremaWithinLimit() {
        var values = Array(repeating: 0.5, count: 120)
        values[24] = 0.98
        values[25] = 0.02
        values[84] = 0.95
        values[85] = 0.05
        let input = points(values: values)

        let reduced = TrendPointReducer.reduce(input, maximumCount: 20)

        XCTAssertLessThanOrEqual(reduced.count, 20)
        XCTAssertEqual(reduced.first?.sequence, input.first?.sequence)
        XCTAssertEqual(reduced.last?.sequence, input.last?.sequence)
        XCTAssertTrue(reduced.contains { $0.value == 0.98 })
        XCTAssertTrue(reduced.contains { $0.value == 0.02 })
        XCTAssertTrue(reduced.contains { $0.value == 0.95 })
        XCTAssertTrue(reduced.contains { $0.value == 0.05 })
        XCTAssertEqual(reduced.map(\.sequence), reduced.map(\.sequence).sorted())
    }

    func testDefaultLimitBoundsLongHistory() {
        let input = points(values: (0..<360).map { Double($0 % 17) })

        XCTAssertLessThanOrEqual(TrendPointReducer.reduce(input).count, 60)
    }

    private func points(values: [Double]) -> [HistoryPoint] {
        let clock = ContinuousClock()
        let start = clock.now
        let wallTime = Date(timeIntervalSince1970: 1_700_000_000)
        return values.enumerated().map { index, value in
            HistoryPoint(
                sequence: UInt64(index + 1),
                wallTime: wallTime.addingTimeInterval(Double(index)),
                monotonicTime: start.advanced(by: .seconds(index)),
                value: value
            )
        }
    }
}

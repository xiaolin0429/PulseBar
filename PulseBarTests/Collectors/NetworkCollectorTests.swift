import os
import XCTest
@testable import PulseBarCore

final class NetworkCollectorTests: XCTestCase {
    func testNetworkRateUsesPrimaryInterfaceAndAccumulatesSession() async {
        let reader = SequenceNetworkReader([
            [interface("lo0", received: 9_999, sent: 9_999, loopback: true), interface("en0", received: 100, sent: 200)],
            [interface("en0", received: 500, sent: 400)]
        ])
        let collector = NetworkCollector(
            counterReader: reader,
            interfaceResolver: FixedInterfaceResolver(name: "en0"),
            pathReader: FixedPathReader(path: NetworkPathState(status: .online, interfaceKind: .wifi))
        )
        let start = ContinuousClock().now
        guard case let .available(first) = await collector.sample(at: start) else {
            return XCTFail("Expected network warmup snapshot")
        }
        XCTAssertEqual(first.rateState, .warmingUp)

        guard case let .available(second) = await collector.sample(
            at: start.advanced(by: .seconds(2))
        ) else { return XCTFail("Expected network snapshot") }
        XCTAssertEqual(second.downloadBytesPerSecond, 200)
        XCTAssertEqual(second.uploadBytesPerSecond, 100)
        XCTAssertEqual(second.sessionDownloadedBytes, 400)
        XCTAssertEqual(second.interface?.kind, .wifi)
    }

    func testInterfaceSwitchWarmsAndDoesNotCrossSubtract() async {
        let reader = SequenceNetworkReader([
            [interface("en0", received: 1_000, sent: 1_000)],
            [interface("utun3", received: 9_000_000, sent: 8_000_000)]
        ])
        let resolver = ChangingInterfaceResolver(names: ["en0", "utun3"])
        let collector = NetworkCollector(
            counterReader: reader,
            interfaceResolver: resolver,
            pathReader: FixedPathReader(path: NetworkPathState(status: .online, interfaceKind: .other))
        )
        let start = ContinuousClock().now
        _ = await collector.sample(at: start)
        guard case let .available(snapshot) = await collector.sample(
            at: start.advanced(by: .seconds(1))
        ) else { return XCTFail("Expected network snapshot") }
        XCTAssertEqual(snapshot.rateState, .warmingUp)
        XCTAssertNil(snapshot.downloadBytesPerSecond)
        XCTAssertEqual(snapshot.interface?.kind, .vpn)
    }

    func testOfflinePathReportsZeroAndResetsBaseline() async {
        let collector = NetworkCollector(
            counterReader: SequenceNetworkReader([]),
            interfaceResolver: FixedInterfaceResolver(name: nil),
            pathReader: FixedPathReader(path: NetworkPathState(status: .offline, interfaceKind: .unknown))
        )
        guard case let .available(snapshot) = await collector.sample(at: ContinuousClock().now) else {
            return XCTFail("Expected offline snapshot")
        }
        XCTAssertEqual(snapshot.pathStatus, .offline)
        XCTAssertEqual(snapshot.downloadBytesPerSecond, 0)
    }
}

private final class ChangingInterfaceResolver: PrimaryInterfaceResolving, Sendable {
    private let names: OSAllocatedUnfairLock<[String]>

    init(names: [String]) {
        self.names = OSAllocatedUnfairLock(initialState: names)
    }

    func primaryInterfaceName() -> String? {
        names.withLock { values in values.isEmpty ? nil : values.removeFirst() }
    }
}

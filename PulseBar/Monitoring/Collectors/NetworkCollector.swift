import Foundation

public actor NetworkCollector {
    private let counterReader: any NetworkRawReading
    private let interfaceResolver: any PrimaryInterfaceResolving
    private let pathReader: any NetworkPathReading
    private var previous: InterfaceCounter?
    private var previousInstant: ContinuousClock.Instant?
    private var sessionDownloadedBytes: UInt64 = 0
    private var sessionUploadedBytes: UInt64 = 0

    public init(
        counterReader: any NetworkRawReading = BSDInterfaceCounterReader(),
        interfaceResolver: any PrimaryInterfaceResolving = SystemPrimaryInterfaceResolver(),
        pathReader: any NetworkPathReading = SystemNetworkPathMonitor()
    ) {
        self.counterReader = counterReader
        self.interfaceResolver = interfaceResolver
        self.pathReader = pathReader
    }

    /// 按当前选中接口的字节增量与实际时间间隔计算上下行 B/s。
    /// 离线返回零速率；接口切换、计数回退或无有效间隔时重建基线，会话累计只包含有效差值。
    public func sample(at instant: ContinuousClock.Instant) async -> MetricValue<NetworkSnapshot> {
        let path = await pathReader.currentPath()
        if path.status == .offline {
            previous = nil
            previousInstant = nil
            return .available(
                NetworkSnapshot(
                    pathStatus: .offline,
                    interface: nil,
                    downloadBytesPerSecond: 0,
                    uploadBytesPerSecond: 0,
                    sessionDownloadedBytes: sessionDownloadedBytes,
                    sessionUploadedBytes: sessionUploadedBytes,
                    localAddresses: [],
                    rateState: .available
                )
            )
        }

        do {
            let counters = try counterReader.readInterfaceCounters().filter {
                !$0.isLoopback && $0.isUp && $0.isRunning
            }
            guard let selected = selectInterface(from: counters) else {
                previous = nil
                previousInstant = nil
                return .unavailable(
                    MetricFailure(
                        code: .sourceMissing,
                        userMessageKey: "metric.network.interfaceUnavailable"
                    )
                )
            }
            let interface = NetworkInterfaceSnapshot(
                name: selected.name,
                kind: interfaceKind(name: selected.name, path: path),
                receivedBytes: selected.receivedBytes,
                sentBytes: selected.sentBytes
            )

            guard let previous,
                  let previousInstant,
                  previous.name == selected.name,
                  selected.receivedBytes >= previous.receivedBytes,
                  selected.sentBytes >= previous.sentBytes else {
                self.previous = selected
                self.previousInstant = instant
                return .available(
                    snapshot(path: path, interface: interface, state: .warmingUp)
                )
            }

            let elapsed = previousInstant.duration(to: instant).secondsValue
            guard elapsed > 0 else {
                self.previous = selected
                self.previousInstant = instant
                return .available(
                    snapshot(path: path, interface: interface, state: .warmingUp)
                )
            }
            let receivedDelta = selected.receivedBytes - previous.receivedBytes
            let sentDelta = selected.sentBytes - previous.sentBytes
            sessionDownloadedBytes = saturatingAdd(sessionDownloadedBytes, receivedDelta)
            sessionUploadedBytes = saturatingAdd(sessionUploadedBytes, sentDelta)
            self.previous = selected
            self.previousInstant = instant
            return .available(
                NetworkSnapshot(
                    pathStatus: path.status,
                    interface: interface,
                    downloadBytesPerSecond: Double(receivedDelta) / elapsed,
                    uploadBytesPerSecond: Double(sentDelta) / elapsed,
                    sessionDownloadedBytes: sessionDownloadedBytes,
                    sessionUploadedBytes: sessionUploadedBytes,
                    localAddresses: [],
                    rateState: .available
                )
            )
        } catch {
            previous = nil
            previousInstant = nil
            return .unavailable(.reading(error, source: "Network"))
        }
    }

    /// 清除接口及时间基线，但保留本次运行期间已累计的有效流量。
    public func resetBaseline() {
        previous = nil
        previousInstant = nil
    }

    /// 优先使用系统主接口；不可用时按 VPN、以太网类接口、其他接口的顺序选择。
    private func selectInterface(from counters: [InterfaceCounter]) -> InterfaceCounter? {
        if let primaryName = interfaceResolver.primaryInterfaceName(),
           let primary = counters.first(where: { $0.name == primaryName }) {
            return primary
        }
        return counters.sorted { interfacePriority($0.name) < interfacePriority($1.name) }.first
    }

    private func interfacePriority(_ name: String) -> String {
        let rank: Int
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") {
            rank = 0
        } else if name.hasPrefix("en") {
            rank = 1
        } else {
            rank = 2
        }
        return "\(rank)-\(name)"
    }

    private func interfaceKind(
        name: String,
        path: NetworkPathState
    ) -> NetworkInterfaceKind {
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") {
            return .vpn
        }
        if path.interfaceKind != .unknown && path.interfaceKind != .other {
            return path.interfaceKind
        }
        if name.hasPrefix("en") { return .wired }
        return .other
    }

    private func snapshot(
        path: NetworkPathState,
        interface: NetworkInterfaceSnapshot,
        state: RateMetricState
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            pathStatus: path.status,
            interface: interface,
            downloadBytesPerSecond: nil,
            uploadBytesPerSecond: nil,
            sessionDownloadedBytes: sessionDownloadedBytes,
            sessionUploadedBytes: sessionUploadedBytes,
            localAddresses: [],
            rateState: state
        )
    }

    private func saturatingAdd(_ left: UInt64, _ right: UInt64) -> UInt64 {
        let result = left.addingReportingOverflow(right)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

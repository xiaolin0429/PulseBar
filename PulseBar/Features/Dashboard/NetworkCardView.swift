import SwiftUI

struct NetworkCardView: View {
    let metric: MetricValue<NetworkSnapshot>
    let downloadHistory: [HistoryPoint]
    let uploadHistory: [HistoryPoint]
    @State private var explanationExpanded = false
    @Environment(\.unitSystem) private var unitSystem
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MetricCardView(title: "网络", systemImage: "network", tint: .teal) {
            MetricStateView(value: metric) { snapshot in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(statusLabel(snapshot.pathStatus), systemImage: statusIcon(snapshot.pathStatus))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(statusColor(snapshot.pathStatus))
                        Spacer()
                        if let interface = snapshot.interface {
                            Text("\(interface.name) · \(kindLabel(interface.kind))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 28) {
                        speed(
                            title: "下载",
                            symbol: "arrow.down",
                            value: snapshot.downloadBytesPerSecond,
                            color: .teal
                        )
                        speed(
                            title: "上传",
                            symbol: "arrow.up",
                            value: snapshot.uploadBytesPerSecond,
                            color: .pink
                        )
                    }

                    if snapshot.rateState == .warmingUp {
                        Text("接口已切换，正在建立新基线…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ThroughputTrendChart(
                        primary: downloadHistory,
                        secondary: uploadHistory,
                        primaryName: String(localized: "下载", locale: locale),
                        secondaryName: String(localized: "上传", locale: locale),
                        primaryColor: .teal,
                        secondaryColor: .pink
                    )

                    HStack {
                        MetricValueRow(
                            label: "本次下载",
                            value: MetricFormatter.bytes(
                                snapshot.sessionDownloadedBytes,
                                unitSystem: unitSystem
                            )
                        )
                        MetricValueRow(
                            label: "本次上传",
                            value: MetricFormatter.bytes(
                                snapshot.sessionUploadedBytes,
                                unitSystem: unitSystem
                            )
                        )
                    }

                    DisclosureGroup(
                        isExpanded: DashboardMotion.expansionBinding(
                            $explanationExpanded,
                            reduceMotion: reduceMotion
                        )
                    ) {
                        Text(
                            "自动模式仅统计系统当前主接口，切换 Wi‑Fi、以太网或 VPN 时会重建基线。本次累计量只包含 PulseBar 运行期间观察到的有效差值，不是开机总流量。"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    } label: {
                        Label("指标口径", systemImage: "info.circle")
                            .font(.caption)
                    }
                }
            }
        }
    }

    /// 构建上传或下载速率块，使用当前单位设置；预热等缺失值显示占位符。
    private func speed(
        title: LocalizedStringKey,
        symbol: String,
        value: Double?,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(color)
            Text(value.map { MetricFormatter.bytesPerSecond($0, unitSystem: unitSystem) } ?? "—")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    /// 将路径状态映射为本地化连接说明，保留未知与待连接的区别。
    private func statusLabel(_ status: NetworkPathStatus) -> LocalizedStringKey {
        switch status {
        case .online: "在线"
        case .offline: "离线"
        case .requiresConnection: "需要连接"
        case .unknown: "正在确认"
        }
    }

    /// 为网络状态选择系统图标，确保离线与未知状态不只依赖颜色区分。
    private func statusIcon(_ status: NetworkPathStatus) -> String {
        switch status {
        case .online: "checkmark.circle.fill"
        case .offline: "wifi.slash"
        case .requiresConnection: "exclamationmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    /// 将在线、离线、待连接与未知状态映射为对应提示颜色。
    private func statusColor(_ status: NetworkPathStatus) -> Color {
        switch status {
        case .online: .green
        case .offline: .red
        case .requiresConnection: .orange
        case .unknown: .secondary
        }
    }

    /// 生成接口类型标签，将两种有线类型统一显示为 Ethernet。
    private func kindLabel(_ kind: NetworkInterfaceKind) -> String {
        switch kind {
        case .wifi: "Wi‑Fi"
        case .ethernet, .wired: "Ethernet"
        case .vpn: "VPN"
        case .cellular: "Cellular"
        case .other: "Other"
        case .unknown: "Unknown"
        }
    }
}

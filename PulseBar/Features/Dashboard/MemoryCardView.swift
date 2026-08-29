import SwiftUI

struct MemoryCardView: View {
    let metric: MetricValue<MemorySnapshot>
    let history: [HistoryPoint]
    @State private var detailsExpanded = false
    @State private var explanationExpanded = false
    @Environment(\.unitSystem) private var unitSystem
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MetricCardView(title: "内存", systemImage: "memorychip", tint: .purple) {
            MetricStateView(value: metric) { snapshot in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(percent(snapshot.usageRatio))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(
                            "\(bytes(snapshot.usedApproximationBytes)) / " +
                            bytes(snapshot.physicalTotalBytes)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        Spacer()
                        PressureBadge(state: snapshot.pressure)
                    }

                    ProgressView(value: snapshot.usageRatio)
                        .tint(pressureColor(snapshot.pressure))

                    PercentTrendChart(points: history, color: .purple, accessibilityName: "内存占用趋势")

                    DisclosureGroup(
                        isExpanded: DashboardMotion.expansionBinding(
                            $detailsExpanded,
                            reduceMotion: reduceMotion
                        )
                    ) {
                        VStack(spacing: 6) {
                            MetricValueRow(
                                label: "可用",
                                value: bytes(snapshot.availableApproximationBytes)
                            )
                            MetricValueRow(label: "活跃", value: bytes(snapshot.activeBytes))
                            MetricValueRow(label: "非活跃", value: bytes(snapshot.inactiveBytes))
                            MetricValueRow(label: "联动", value: bytes(snapshot.wiredBytes))
                            MetricValueRow(label: "压缩", value: bytes(snapshot.compressedBytes))
                            MetricValueRow(label: "可清除", value: bytes(snapshot.purgeableBytes))
                            MetricValueRow(
                                label: "交换空间",
                                value: swapDescription(snapshot)
                            )
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("内存拆分")
                            .font(.caption)
                    }

                    DisclosureGroup(
                        isExpanded: DashboardMotion.expansionBinding(
                            $explanationExpanded,
                            reduceMotion: reduceMotion
                        )
                    ) {
                        Text(
                            "macOS 会将空闲内存用于缓存，空闲较少不一定异常。PulseBar 的占用值由公开 VM 计数器近似计算；内存压力、压缩与交换空间通常更能反映系统是否紧张。"
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

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func pressureColor(_ state: MemoryPressureState) -> Color {
        switch state {
        case .normal, .unknown: .purple
        case .warning: .orange
        case .critical: .red
        }
    }

    private func swapDescription(_ snapshot: MemorySnapshot) -> String {
        guard let used = snapshot.swapUsedBytes, let total = snapshot.swapTotalBytes else {
            return String(localized: "不可用", locale: locale)
        }
        return "\(bytes(used)) / \(bytes(total))"
    }

    private func bytes(_ value: UInt64) -> String {
        MetricFormatter.bytes(value, unitSystem: unitSystem)
    }
}

private struct PressureBadge: View {
    let state: MemoryPressureState

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var label: LocalizedStringKey {
        switch state {
        case .normal: "压力正常"
        case .warning: "压力警告"
        case .critical: "压力严重"
        case .unknown: "压力未知"
        }
    }

    private var icon: String {
        switch state {
        case .normal: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch state {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }
}

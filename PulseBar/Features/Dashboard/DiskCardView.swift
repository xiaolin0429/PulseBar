import SwiftUI

struct DiskCardView: View {
    let metric: MetricValue<DiskSnapshot>
    let readHistory: [HistoryPoint]
    let writeHistory: [HistoryPoint]
    @State private var volumesExpanded = false
    @State private var explanationExpanded = false

    var body: some View {
        MetricCardView(title: "磁盘", systemImage: "internaldrive", tint: .orange) {
            MetricStateView(value: metric) { snapshot in
                VStack(alignment: .leading, spacing: 10) {
                    if let volume = snapshot.primaryVolume {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MetricFormatter.bytes(volume.availableCapacityBytes))
                                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text("可用 · \(volume.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("已用 \(percent(volume.usageRatio))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(value: volume.usageRatio)
                            .tint(volume.usageRatio >= 0.9 ? .orange : .accentColor)
                    }

                    HStack(spacing: 18) {
                        rateLabel(
                            title: "读取",
                            symbol: "arrow.down",
                            value: snapshot.aggregateReadBytesPerSecond,
                            color: .cyan
                        )
                        rateLabel(
                            title: "写入",
                            symbol: "arrow.up",
                            value: snapshot.aggregateWriteBytesPerSecond,
                            color: .orange
                        )
                    }

                    if case let .unavailable(failure) = snapshot.ioState {
                        Label("I/O 速率不可用，容量仍可正常读取", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(failure.debugContext ?? failure.userMessageKey)
                    } else if snapshot.ioState == .warmingUp {
                        Text("正在建立磁盘速率基线…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ThroughputTrendChart(
                        primary: readHistory,
                        secondary: writeHistory,
                        primaryName: "读取",
                        secondaryName: "写入",
                        primaryColor: .cyan,
                        secondaryColor: .orange
                    )

                    DisclosureGroup(isExpanded: $volumesExpanded) {
                        VStack(spacing: 6) {
                            ForEach(snapshot.volumes) { volume in
                                HStack {
                                    Image(systemName: volume.isRemovable == true ? "externaldrive" : "internaldrive")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(volume.name)
                                        Text(volume.mountPathDisplayName)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(MetricFormatter.bytes(volume.availableCapacityBytes))
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("已挂载本地卷（\(snapshot.volumes.count)）")
                            .font(.caption)
                    }

                    DisclosureGroup(isExpanded: $explanationExpanded) {
                        Text(
                            "容量优先使用系统提供的“可用于重要用途”数值；APFS 快照和可清除空间可能令其与 Finder 略有差异。读写速率来自块存储累计计数器。"
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

    private func rateLabel(
        title: LocalizedStringKey,
        symbol: String,
        value: Double?,
        color: Color
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value.map { MetricFormatter.bytesPerSecond($0) } ?? "—")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
        }
    }

    private func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}

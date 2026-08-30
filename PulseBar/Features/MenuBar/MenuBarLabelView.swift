import SwiftUI

struct MenuBarLabelView: View {
    let summary: MenuBarSummary
    let preferences: MenuBarPreferences
    @Environment(\.locale) private var locale

    var body: some View {
        visualLabel
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    @ViewBuilder
    private var visualLabel: some View {
        if preferences.preset == .compact {
            Text(compactLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        } else if displayedModules.isEmpty {
            Text("PulseBar")
                .font(.system(size: 11, weight: .medium, design: .rounded))
        } else {
            HStack(spacing: 5) {
                ForEach(displayedModules) { module in
                    moduleTile(module)
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var compactLabel: String {
        let modules = displayedModules.compactMap(compactLabel(for:))
        return modules.isEmpty ? "PulseBar" : modules.joined(separator: separator)
    }

    private var separator: String {
        " · "
    }

    private var displayedModules: [MenuBarModule] {
        preferences.visibleModules.filter { module in
            module != .disk || preferences.preset == .complete
        }
    }

    @ViewBuilder
    private func moduleTile(_ module: MenuBarModule) -> some View {
        switch module {
        case .cpu:
            metricTile(value: summary.cpuPercent.map(percent) ?? "—", label: "CPU")
        case .memory:
            metricTile(value: summary.memoryPercent.map(percent) ?? "—", label: "MEM")
        case .disk:
            metricTile(value: compactDisk, label: "SSD")
        case .network:
            networkTile
        }
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(spacing: -2) {
            Text(verbatim: value)
            Text(verbatim: label)
        }
        .frame(minWidth: 25)
    }

    private var networkTile: some View {
        VStack(alignment: .leading, spacing: -2) {
            networkRow(arrow: "↑", value: compactUpload)
            networkRow(arrow: "↓", value: compactDownload)
        }
    }

    private func networkRow(arrow: String, value: String) -> some View {
        HStack(spacing: 1) {
            Text(verbatim: arrow)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .frame(width: 8)
            Text(verbatim: value)
        }
    }

    private func compactLabel(for module: MenuBarModule) -> String? {
        switch module {
        case .cpu:
            summary.cpuPercent.map(percent) ?? "—"
        case .memory:
            summary.memoryPercent.map(percent) ?? "—"
        case .disk:
            compactDisk
        case .network:
            "↓\(compactDownload)"
        }
    }

    private var compactDisk: String {
        summary.diskFreeBytes.map {
            MetricFormatter.compactBytes($0, unitSystem: preferences.unitSystem)
        } ?? "—"
    }

    private var compactDownload: String {
        summary.downloadBytesPerSecond.map {
            MetricFormatter.compactBytesPerSecond($0, unitSystem: preferences.unitSystem)
        } ?? "—"
    }

    private var compactUpload: String {
        summary.uploadBytesPerSecond.map {
            MetricFormatter.compactBytesPerSecond($0, unitSystem: preferences.unitSystem)
        } ?? "—"
    }

    private var accessibilityLabel: String {
        let unavailable = String(localized: "不可用", locale: locale)
        let cpu = summary.cpuPercent.map(percent) ?? unavailable
        let memory = summary.memoryPercent.map(percent) ?? unavailable
        let download = summary.downloadBytesPerSecond.map {
            MetricFormatter.bytesPerSecond($0, unitSystem: preferences.unitSystem)
        } ?? unavailable
        let upload = summary.uploadBytesPerSecond.map {
            MetricFormatter.bytesPerSecond($0, unitSystem: preferences.unitSystem)
        } ?? unavailable
        return String(
            localized: "CPU \(cpu)，内存 \(memory)，下载 \(download)，上传 \(upload)",
            locale: locale
        )
    }

    private func percent(_ value: Double) -> String {
        let digits = preferences.showDecimals ? 1 : 0
        return "\(value.formatted(.number.precision(.fractionLength(digits))))%"
    }

    private var color: Color {
        switch summary.severity {
        case .normal: .primary
        case .warning: .yellow
        case .critical: .red
        }
    }
}

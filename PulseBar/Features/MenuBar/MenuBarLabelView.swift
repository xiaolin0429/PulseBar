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
            Text(verbatim: twoLineLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .lineLimit(2)
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

    private var twoLineLabel: String {
        MetricFormatter.twoLineLabel(
            columns: displayedModules.map(twoLineColumn(for:))
        )
    }

    private func twoLineColumn(for module: MenuBarModule) -> MetricFormatter.TwoLineColumn {
        switch module {
        case .cpu:
            MetricFormatter.TwoLineColumn(
                top: summary.cpuPercent.map(percent) ?? "—",
                bottom: "CPU"
            )
        case .memory:
            MetricFormatter.TwoLineColumn(
                top: summary.memoryPercent.map(percent) ?? "—",
                bottom: "MEM"
            )
        case .disk:
            MetricFormatter.TwoLineColumn(top: compactDisk, bottom: "SSD")
        case .network:
            MetricFormatter.TwoLineColumn(
                top: "↑\(compactUpload)",
                bottom: "↓\(compactDownload)"
            )
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

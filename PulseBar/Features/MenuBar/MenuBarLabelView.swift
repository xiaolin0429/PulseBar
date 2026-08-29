import SwiftUI

struct MenuBarLabelView: View {
    let summary: MenuBarSummary
    let preferences: MenuBarPreferences
    @Environment(\.locale) private var locale

    var body: some View {
        Text(label)
            .monospacedDigit()
            .foregroundStyle(color)
            .accessibilityLabel(accessibilityLabel)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var label: String {
        let modules = preferences.visibleModules.compactMap(label(for:))
        return modules.isEmpty ? "PulseBar" : modules.joined(separator: separator)
    }

    private var separator: String {
        preferences.preset == .compact ? " · " : "  "
    }

    private func label(for module: MenuBarModule) -> String? {
        switch module {
        case .cpu:
            let value = summary.cpuPercent.map(percent) ?? "—"
            return preferences.preset == .compact ? value : "CPU \(value)"
        case .memory:
            let value = summary.memoryPercent.map(percent) ?? "—"
            return preferences.preset == .compact ? value : "MEM \(value)"
        case .disk:
            guard preferences.preset == .complete else { return nil }
            let value = summary.diskFreeBytes.map {
                MetricFormatter.bytes($0, unitSystem: preferences.unitSystem)
            } ?? "—"
            return "SSD \(value)"
        case .network:
            let download = summary.downloadBytesPerSecond.map {
                MetricFormatter.bytesPerSecond($0, unitSystem: preferences.unitSystem)
            } ?? "—"
            let upload = summary.uploadBytesPerSecond.map {
                MetricFormatter.bytesPerSecond($0, unitSystem: preferences.unitSystem)
            } ?? "—"
            return preferences.preset == .compact ? "↓\(download)" : "↓ \(download)  ↑ \(upload)"
        }
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

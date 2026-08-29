import SwiftUI

struct MenuBarLabelView: View {
    let summary: MenuBarSummary
    let preferences: MenuBarPreferences

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
            let value = summary.cpuPercent.map { "\($0)%" } ?? "—"
            return preferences.preset == .compact ? value : "CPU \(value)"
        case .memory:
            let value = summary.memoryPercent.map { "\($0)%" } ?? "—"
            return preferences.preset == .compact ? value : "MEM \(value)"
        case .disk:
            guard preferences.preset == .complete else { return nil }
            let value = summary.diskFreeBytes.map { MetricFormatter.bytes($0) } ?? "—"
            return "SSD \(value)"
        case .network:
            let download = summary.downloadBytesPerSecond.map {
                MetricFormatter.bytesPerSecond($0)
            } ?? "—"
            let upload = summary.uploadBytesPerSecond.map {
                MetricFormatter.bytesPerSecond($0)
            } ?? "—"
            return preferences.preset == .compact ? "↓\(download)" : "↓ \(download)  ↑ \(upload)"
        }
    }

    private var accessibilityLabel: String {
        let cpu = summary.cpuPercent.map(String.init) ?? "不可用"
        let memory = summary.memoryPercent.map(String.init) ?? "不可用"
        let download = summary.downloadBytesPerSecond.map {
            MetricFormatter.bytesPerSecond($0)
        } ?? "不可用"
        let upload = summary.uploadBytesPerSecond.map {
            MetricFormatter.bytesPerSecond($0)
        } ?? "不可用"
        return "CPU \(cpu)%，内存 \(memory)%，下载 \(download)，上传 \(upload)"
    }

    private var color: Color {
        switch summary.severity {
        case .normal: .primary
        case .warning: .yellow
        case .critical: .red
        }
    }
}

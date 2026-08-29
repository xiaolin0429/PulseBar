import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PulseBar")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.togglePaused()
                } label: {
                    Image(systemName: model.monitoringState == .paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .help(model.monitoringState == .paused ? "继续监控" : "暂停监控")
            }

            GroupBox("实时采集") {
                if let snapshot = model.latest {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Label("CPU", systemImage: "cpu")
                            Text(percent(snapshot.cpu.availableValue?.totalUsageRatio))
                                .monospacedDigit()
                        }
                        GridRow {
                            Label("内存", systemImage: "memorychip")
                            Text(percent(snapshot.memory.availableValue?.usageRatio))
                                .monospacedDigit()
                        }
                        GridRow {
                            Label("磁盘可用", systemImage: "internaldrive")
                            Text(
                                snapshot.disk.availableValue?.primaryVolume
                                    .map { MetricFormatter.bytes($0.availableCapacityBytes) } ?? "—"
                            )
                            .monospacedDigit()
                        }
                        GridRow {
                            Label("网络", systemImage: "network")
                            Text(
                                snapshot.network.availableValue?.downloadBytesPerSecond
                                    .map { "↓ \(MetricFormatter.bytesPerSecond($0))" } ?? "—"
                            )
                            .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在建立采样基线…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            HStack {
                Button("设置") {
                    NSApplication.shared.sendAction(
                        Selector(("showSettingsWindow:")),
                        to: nil,
                        from: nil
                    )
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("退出 PulseBar") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear { model.setDashboardVisible(true) }
        .onDisappear { model.setDashboardVisible(false) }
    }

    private var statusText: String {
        switch model.monitoringState {
        case .monitoring: "监控中"
        case .paused: "已暂停"
        case .partiallyUnavailable: "部分指标不可用"
        }
    }

    private func percent(_ ratio: Double?) -> String {
        ratio.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }
}

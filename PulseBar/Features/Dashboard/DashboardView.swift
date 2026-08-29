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

            GroupBox("项目骨架") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("单一 MenuBarExtra", systemImage: "menubar.rectangle")
                    Label("AppModel 单向状态发布", systemImage: "arrow.triangle.2.circlepath")
                    Label("系统采集将在下一里程碑接入", systemImage: "wrench.and.screwdriver")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
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
    }

    private var statusText: String {
        switch model.monitoringState {
        case .preview: "预览数据 · 框架验证"
        case .monitoring: "监控中"
        case .paused: "已暂停"
        case .partiallyUnavailable: "部分指标不可用"
        }
    }
}

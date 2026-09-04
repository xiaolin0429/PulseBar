import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var presentation: DashboardPresentationState
    @Environment(\.locale) private var locale

    /// 隐藏时移除卡片子树，仅保留占位尺寸，让图表视图及其展示数据有机会释放。
    var body: some View {
        Group {
            if presentation.isVisible {
                dashboardContent
            } else {
                Color.clear
                    .frame(width: 420)
                    .frame(minHeight: 500, idealHeight: 650, maxHeight: 720)
            }
        }
        .onAppear { model.setDashboardVisible(true) }
        .onDisappear { model.setDashboardVisible(false) }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                if let snapshot = presentation.latest {
                    VStack(spacing: 12) {
                        CPUCardView(metric: snapshot.cpu, history: presentation.history.cpuUsage)
                        MemoryCardView(metric: snapshot.memory, history: presentation.history.memoryUsage)
                        DiskCardView(
                            metric: snapshot.disk,
                            readHistory: presentation.history.diskRead,
                            writeHistory: presentation.history.diskWrite
                        )
                        NetworkCardView(
                            metric: snapshot.network,
                            downloadHistory: presentation.history.networkDownload,
                            uploadHistory: presentation.history.networkUpload
                        )
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("正在读取系统指标…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.65))
            Divider()
            footer
        }
        .frame(width: 420)
        .frame(minHeight: 500, idealHeight: 650, maxHeight: 720)
        .accessibilityIdentifier("dashboard")
    }

    private var header: some View {
        let monitoringAction = model.monitoringState == .paused
            ? String(localized: "继续监控", locale: locale)
            : String(localized: "暂停监控", locale: locale)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Host.current().localizedName ?? "Mac")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                    if let snapshot = presentation.latest {
                        Text("·")
                        Text(snapshot.wallTime.formatted(.relative(presentation: .numeric)))
                    }
                    Text("· 运行 \(uptime)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.togglePaused()
            } label: {
                Image(systemName: model.monitoringState == .paused ? "play.fill" : "pause.fill")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help(monitoringAction)
            .accessibilityLabel(monitoringAction)
            .accessibilityIdentifier("dashboard.monitoring.toggle")

            settingsButton
            .buttonStyle(.borderless)
            .help("打开设置")
            .accessibilityLabel("打开设置")
            .accessibilityIdentifier("dashboard.settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var settingsButton: some View {
        SettingsWindowButton {
            settingsButtonLabel
        }
    }

    private var settingsButtonLabel: some View {
        Image(systemName: "gearshape")
            .frame(width: 16, height: 16)
    }

    private var footer: some View {
        HStack {
            Button {
                AppActions.openActivityMonitor()
            } label: {
                Label("活动监视器", systemImage: "waveform.path.ecg.rectangle")
            }
            .buttonStyle(.borderless)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusText: LocalizedStringKey {
        switch model.monitoringState {
        case .monitoring: "监控中"
        case .paused: "已暂停"
        case .partiallyUnavailable: "部分指标不可用"
        }
    }

    private var statusColor: Color {
        switch model.monitoringState {
        case .monitoring: .green
        case .paused: .orange
        case .partiallyUnavailable: .yellow
        }
    }

    private var uptime: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return String(localized: "\(days)天 \(hours)小时", locale: locale)
        }
        if hours > 0 {
            return String(localized: "\(hours)小时 \(minutes)分", locale: locale)
        }
        return String(localized: "\(minutes)分钟", locale: locale)
    }
}

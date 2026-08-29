import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("欢迎使用 PulseBar")
                    .font(.largeTitle.bold())
                Text("在菜单栏中轻量、透明地查看核心系统状态")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                onboardingFeature("CPU 与内存", icon: "cpu")
                onboardingFeature("磁盘与网络", icon: "internaldrive")
                onboardingFeature("最近趋势", icon: "chart.xyaxis.line")
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("所有数据只在本机内存中处理，不会上传", systemImage: "hand.raised.fill")
                Label("不需要管理员、完全磁盘访问或辅助功能权限", systemImage: "lock.shield.fill")
                Label("默认菜单栏显示 CPU、内存与网络", systemImage: "menubar.rectangle")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))

            Toggle(
                "登录时自动启动",
                isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .accessibilityIdentifier("onboarding.launchAtLogin")

            HStack {
                MenuBarLabelView(
                    summary: .preview,
                    preferences: model.menuBarPreferences
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .accessibilityLabel("菜单栏预览")
                Spacer()
                Button("开始使用") {
                    model.completeOnboarding()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding.start")
            }
        }
        .padding(28)
        .frame(width: 560)
        .accessibilityIdentifier("onboarding")
    }

    private func onboardingFeature(_ title: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }
}

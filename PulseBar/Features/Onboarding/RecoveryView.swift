import AppKit
import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("PulseBar 已恢复到菜单栏")
                .font(.title2.bold())
            Text("如果菜单栏空间不足，macOS 可能会暂时隐藏部分项目。你可以使用简洁密度或减少显示模块。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Text("系统设置路径：控制中心 > 仅菜单栏")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack {
                SettingsWindowButton(beforeOpen: {
                    model.dismissRecoveryNotice()
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Text("打开设置")
                }
                Spacer()
                Button("知道了") {
                    model.dismissRecoveryNotice()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
    }
}

import AppKit
import SwiftUI

@MainActor
enum AppActions {
    /// 通过响应链请求创建设置窗口，作为 macOS 13 的兼容入口。
    static func openSettings() {
        openSettings {
            NSApplication.shared.sendAction(
                Selector(("showSettingsWindow:")),
                to: nil,
                from: nil
            )
        }
    }

    /// 经应用代理复用或创建设置窗口；代理尚未就绪时直接创建并激活应用。
    static func openSettings(createIfNeeded: () -> Void) {
        if let appDelegate = AppDelegate.shared {
            appDelegate.openSettings(createIfNeeded: createIfNeeded)
        } else {
            createIfNeeded()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    /// 打开系统自带的活动监视器，供用户核对进程及资源占用。
    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }
}

struct SettingsWindowButton<Label: View>: View {
    private let beforeOpen: () -> Void
    private let label: () -> Label

    /// 封装设置按钮标签与打开前动作，例如由调用方先关闭当前弹出界面。
    init(
        beforeOpen: @escaping () -> Void = {},
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.beforeOpen = beforeOpen
        self.label = label
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 14.0, *) {
            ModernSettingsWindowButton(beforeOpen: beforeOpen, label: label)
        } else {
            Button {
                beforeOpen()
                AppActions.openSettings()
            } label: {
                label()
            }
        }
    }
}

@available(macOS 14.0, *)
private struct ModernSettingsWindowButton<Label: View>: View {
    @Environment(\.openSettings) private var openSettings

    let beforeOpen: () -> Void
    let label: () -> Label

    var body: some View {
        Button {
            beforeOpen()
            AppActions.openSettings {
                openSettings()
            }
        } label: {
            label()
        }
    }
}

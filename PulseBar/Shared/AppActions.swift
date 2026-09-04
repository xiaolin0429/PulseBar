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

    static func openSettings(createIfNeeded: () -> Void) {
        if let appDelegate = AppDelegate.shared {
            appDelegate.openSettings(createIfNeeded: createIfNeeded)
        } else {
            createIfNeeded()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }
}

struct SettingsWindowButton<Label: View>: View {
    private let beforeOpen: () -> Void
    private let label: () -> Label

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

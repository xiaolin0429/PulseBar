import AppKit

@MainActor
enum AppActions {
    static func openSettings() {
        if let appDelegate = AppDelegate.shared {
            appDelegate.showSettingsWindow()
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: nil
        )
    }

    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }
}

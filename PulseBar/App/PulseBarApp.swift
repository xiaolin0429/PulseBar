import AppKit
import SwiftUI

@main
struct PulseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra(isInserted: $model.isMenuBarItemInserted) {
            DashboardView()
                .environmentObject(model)
        } label: {
            MenuBarLabelView(
                summary: model.menuBarSummary,
                preferences: model.menuBarPreferences
            )
            .task { await model.startMonitoring() }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.willSleepNotification
                )
            ) { _ in
                model.prepareForSleep()
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didWakeNotification
                )
            ) { _ in
                model.resumeAfterWake()
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didMountNotification
                )
            ) { _ in
                model.volumeConfigurationChanged()
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didUnmountNotification
                )
            ) { _ in
                model.volumeConfigurationChanged()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

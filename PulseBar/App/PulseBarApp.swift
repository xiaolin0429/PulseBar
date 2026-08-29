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
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

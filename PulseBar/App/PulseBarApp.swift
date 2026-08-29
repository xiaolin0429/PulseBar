import SwiftUI

@main
@MainActor
struct PulseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let appModel = AppModel()
        _model = StateObject(wrappedValue: appModel)
        AppDelegate.model = appModel
    }

    var body: some Scene {
        MenuBarExtra(
            isInserted: Binding(
                get: { model.isMenuBarItemInserted },
                set: { model.setMenuBarItemInserted($0) }
            )
        ) {
            DashboardView()
                .environmentObject(model)
                .environment(\.unitSystem, model.settings.unitSystem)
                .environment(\.locale, model.settings.language.locale ?? .current)
        } label: {
            AppMenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environment(\.unitSystem, model.settings.unitSystem)
                .environment(\.locale, model.settings.language.locale ?? .current)
        }
    }
}

import SwiftUI

@main
@MainActor
struct PulseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    /// 创建唯一的应用模型，并让 AppKit 生命周期代理与 SwiftUI 场景共享该实例。
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
                .environmentObject(model.dashboardPresentation)
                .environment(\.unitSystem, model.settings.unitSystem)
                .environment(\.locale, model.settings.language.locale ?? .current)
        } label: {
            AppMenuBarLabel(
                model: model,
                presentation: model.menuBarPresentation
            )
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

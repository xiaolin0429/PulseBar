struct MenuBarPreferences: Equatable, Sendable {
    var preset: MenuBarPreset = .standard
    var visibleModules: [MenuBarModule] = [.cpu, .memory, .network]
    var showDecimals = false
    var unitSystem: UnitSystem = .mixedDefault

    init(settings: AppSettings = AppSettings()) {
        preset = settings.menuBarPreset
        visibleModules = settings.visibleModules
        showDecimals = settings.showDecimals
        unitSystem = settings.unitSystem
    }
}

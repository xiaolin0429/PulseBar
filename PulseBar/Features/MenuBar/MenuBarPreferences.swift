struct MenuBarPreferences: Equatable, Sendable {
    var preset: MenuBarPreset = .standard
    var visibleModules: [MenuBarModule] = [.cpu, .memory, .network]
    var showDecimals = false
    var unitSystem: UnitSystem = .mixedDefault

    /// 从全量设置提取菜单栏所需字段，避免无关设置进入菜单栏展示模型。
    init(settings: AppSettings = AppSettings()) {
        preset = settings.menuBarPreset
        visibleModules = settings.visibleModules
        showDecimals = settings.showDecimals
        unitSystem = settings.unitSystem
    }
}

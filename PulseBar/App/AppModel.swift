import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isMenuBarItemInserted: Bool {
        didSet {
            settingsRepository.menuBarWasRemoved = !isMenuBarItemInserted
        }
    }
    @Published var settings: AppSettings {
        didSet { settingsDidChange() }
    }
    @Published private(set) var monitoringState: MonitoringState = .monitoring
    @Published private(set) var loginItemStatus: LoginItemStatus
    @Published var systemIntegrationError: String?
    @Published private(set) var shouldShowRecoveryNotice: Bool

    let menuBarPresentation = MenuBarPresentationState()
    let dashboardPresentation = DashboardPresentationState()

    private let coordinator: SamplingCoordinator
    private let settingsRepository: SettingsRepository
    private let loginItemService: any LoginItemServicing
    private var hasStarted = false
    private var onboardingWindowRequested = false
    private var dashboardIsVisible = false
    private var lastSnapshot: SystemSnapshot?

    enum MonitoringState: Equatable {
        case monitoring
        case paused
        case partiallyUnavailable
    }

    /// 载入用户设置并用系统登录项实际状态校准开关，再应用 Dock 显示策略。
    /// 采样延迟到 startMonitoring，避免初始化时启动重复任务。
    init(
        coordinator: SamplingCoordinator = SamplingCoordinator(),
        settingsRepository: SettingsRepository = SettingsRepository(),
        loginItemService: any LoginItemServicing = LoginItemService()
    ) {
        self.coordinator = coordinator
        self.settingsRepository = settingsRepository
        self.loginItemService = loginItemService
        let currentLoginItemStatus = loginItemService.status
        var loadedSettings = settingsRepository.load()
        loadedSettings.launchAtLogin = Self.isLoginItemEnabled(currentLoginItemStatus)
        settings = loadedSettings
        loginItemStatus = currentLoginItemStatus
        shouldShowRecoveryNotice = settingsRepository.menuBarWasRemoved
        isMenuBarItemInserted = true
        settingsRepository.save(loadedSettings)
        applyAppearanceSettings()
    }

    var menuBarPreferences: MenuBarPreferences {
        MenuBarPreferences(settings: settings)
    }

    var needsOnboarding: Bool {
        !settingsRepository.onboardingCompleted && !onboardingWindowRequested
    }

    /// 幂等启动监控，先同步刷新策略与历史窗口，再订阅主线程采样结果。
    func startMonitoring() async {
        guard !hasStarted else { return }
        hasStarted = true
        await coordinator.setRefreshPolicy(settings.refreshPolicy)
        await coordinator.setHistoryWindow(settings.historyWindow)
        await coordinator.start { [weak self] snapshot, history in
            self?.publish(snapshot: snapshot, history: history)
        }
    }

    /// 标记本次运行已请求引导，避免应用启动与菜单栏视图重复弹窗。
    func markOnboardingWindowRequested() {
        onboardingWindowRequested = true
    }

    /// 同步菜单栏项插入状态；属性观察器负责记录是否被移除。
    func setMenuBarItemInserted(_ inserted: Bool) {
        guard isMenuBarItemInserted != inserted else { return }
        isMenuBarItemInserted = inserted
    }

    /// 持久化引导完成状态，并阻止本次运行再次展示引导。
    func completeOnboarding() {
        settingsRepository.onboardingCompleted = true
        onboardingWindowRequested = true
    }

    /// 关闭恢复提醒，同时清除此前菜单栏被移除的持久化标记。
    func dismissRecoveryNotice() {
        shouldShowRecoveryNotice = false
        settingsRepository.menuBarWasRemoved = false
    }

    /// 重新插入菜单栏项并展示恢复提示，帮助用户定位恢复后的入口。
    func restoreMenuBarItem() {
        isMenuBarItemInserted = true
        shouldShowRecoveryNotice = true
        AppDelegate.shared?.showRecoveryWindow()
    }

    /// 切换采样暂停状态；恢复时由协调器重新建立速率基线。
    func togglePaused() {
        Task {
            if monitoringState == .paused {
                await coordinator.resume()
                monitoringState = .monitoring
            } else {
                await coordinator.pause()
                monitoringState = .paused
            }
        }
    }

    /// 同步面板显示状态：打开时先展示最近快照并请求新采样，隐藏时释放展示数据。
    /// 同时通知协调器调整采样频率及历史数组的生成策略。
    func setDashboardVisible(_ visible: Bool) {
        dashboardIsVisible = visible
        if visible {
            dashboardPresentation.show(snapshot: lastSnapshot)
        } else {
            dashboardPresentation.hide()
        }
        Task {
            await coordinator.setDashboardVisible(visible)
            if visible {
                await coordinator.sampleNow()
            }
        }
    }

    /// 把系统即将睡眠事件转交采样协调器。
    func prepareForSleep() {
        Task { await coordinator.prepareForSleep() }
    }

    /// 把系统唤醒事件转交协调器，恢复前重建差分基线。
    func resumeAfterWake() {
        Task { await coordinator.resumeAfterWake() }
    }

    /// 通知协调器卷配置已变更，下一次采样重新读取卷容量。
    func volumeConfigurationChanged() {
        Task { await coordinator.volumeConfigurationChanged() }
    }

    /// 切换模块可见性；拒绝关闭最后一个模块，并提供可本地化的错误提示。
    func toggleModule(_ module: MenuBarModule, visible: Bool) {
        if visible {
            guard !settings.visibleModules.contains(module) else { return }
            settings.visibleModules.append(module)
        } else {
            guard settings.visibleModules.count > 1 else {
                systemIntegrationError = String(
                    localized: "至少保留一个菜单栏模块。",
                    locale: localizationLocale
                )
                return
            }
            settings.visibleModules.removeAll { $0 == module }
        }
    }

    /// 按相对行数移动模块，供键盘、辅助功能或上下移动操作使用。
    func moveModule(_ module: MenuBarModule, offset: Int) {
        settings.moveModule(module, offset: offset)
    }

    /// 将模块移到目标模块所在位置，供拖拽结束后提交新顺序。
    func moveModule(_ module: MenuBarModule, to target: MenuBarModule) {
        settings.moveModule(module, to: target)
    }

    /// 请求修改登录项并回读系统状态；需要批准或执行失败时给出提示。
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            loginItemStatus = loginItemService.status
            settings.launchAtLogin = Self.isLoginItemEnabled(loginItemStatus)
            systemIntegrationError = nil
            if loginItemStatus == .requiresApproval {
                systemIntegrationError = String(
                    localized: "登录项需要在系统设置 > 通用 > 登录项中批准。",
                    locale: localizationLocale
                )
            }
        } catch {
            loginItemStatus = loginItemService.status
            systemIntegrationError = String(
                localized: "无法更改登录启动：\(error.localizedDescription)",
                locale: localizationLocale
            )
        }
    }

    /// 打开系统登录项设置，供用户处理待批准状态。
    func openLoginItemSettings() {
        loginItemService.openSystemSettings()
    }

    /// 恢复应用默认设置并尝试关闭登录项；若系统操作失败，开关保留实际状态。
    func resetSettings() {
        var defaultSettings = settingsRepository.resetSettings()
        if Self.isLoginItemEnabled(loginItemService.status) {
            do {
                try loginItemService.setEnabled(false)
                systemIntegrationError = nil
            } catch {
                systemIntegrationError = String(
                    localized: "无法关闭登录启动：\(error.localizedDescription)",
                    locale: localizationLocale
                )
            }
        }
        loginItemStatus = loginItemService.status
        defaultSettings.launchAtLogin = Self.isLoginItemEnabled(loginItemStatus)
        settings = defaultSettings
    }

    /// 规范化并持久化设置，同步外观和采样配置；有修正时先回写再处理。
    private func settingsDidChange() {
        let normalized = settings.normalized()
        if normalized != settings {
            settings = normalized
            return
        }
        settingsRepository.save(settings)
        applyAppearanceSettings()
        Task {
            await coordinator.setRefreshPolicy(settings.refreshPolicy)
            await coordinator.setHistoryWindow(settings.historyWindow)
        }
    }

    /// 根据偏好切换普通应用或菜单栏辅助应用模式，控制 Dock 图标可见性。
    private func applyAppearanceSettings() {
        NSApplication.shared.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    private var localizationLocale: Locale {
        settings.language.locale ?? .current
    }

    /// 将已注册但待批准也视为已开启请求，避免界面把待批准误显示为关闭。
    private static func isLoginItemEnabled(_ status: LoginItemStatus) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    /// 保存最新快照，按可见性更新面板，并向菜单栏发布轻量摘要。
    /// 监控状态只在实际变化时通知界面，且不会覆盖用户暂停状态。
    private func publish(snapshot: SystemSnapshot, history: DashboardHistory) {
        lastSnapshot = snapshot
        if dashboardIsVisible {
            dashboardPresentation.publish(snapshot: snapshot, history: history)
        }
        let nextMenuBarSummary = MenuBarSummary(snapshot: snapshot)
        menuBarPresentation.publish(nextMenuBarSummary)
        guard monitoringState != .paused else { return }
        let hasFailure = [
            isUnavailable(snapshot.cpu),
            isUnavailable(snapshot.memory),
            isUnavailable(snapshot.disk),
            isUnavailable(snapshot.network)
        ].contains(true)
        let nextState: MonitoringState = hasFailure ? .partiallyUnavailable : .monitoring
        if nextState != monitoringState {
            monitoringState = nextState
        }
    }

    /// 仅识别完全不可用状态；预热和短期旧值不计入此处的失败标志。
    private func isUnavailable<Value: Sendable & Equatable>(
        _ value: MetricValue<Value>
    ) -> Bool {
        if case .unavailable = value { return true }
        return false
    }
}

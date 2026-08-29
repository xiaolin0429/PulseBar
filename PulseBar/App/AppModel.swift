import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isMenuBarItemInserted: Bool {
        didSet {
            settingsRepository.menuBarWasRemoved = !isMenuBarItemInserted
        }
    }
    @Published private(set) var menuBarSummary = MenuBarSummary.unavailable
    @Published var settings: AppSettings {
        didSet { settingsDidChange() }
    }
    @Published private(set) var monitoringState: MonitoringState = .monitoring
    @Published private(set) var latest: SystemSnapshot?
    @Published private(set) var history = DashboardHistory.empty
    @Published private(set) var loginItemStatus: LoginItemStatus
    @Published var systemIntegrationError: String?
    @Published private(set) var shouldShowRecoveryNotice: Bool

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

    func startMonitoring() async {
        guard !hasStarted else { return }
        hasStarted = true
        await coordinator.setRefreshPolicy(settings.refreshPolicy)
        await coordinator.setHistoryWindow(settings.historyWindow)
        await coordinator.start { [weak self] snapshot, history in
            self?.publish(snapshot: snapshot, history: history)
        }
    }

    func markOnboardingWindowRequested() {
        onboardingWindowRequested = true
    }

    func setMenuBarItemInserted(_ inserted: Bool) {
        guard isMenuBarItemInserted != inserted else { return }
        isMenuBarItemInserted = inserted
    }

    func completeOnboarding() {
        settingsRepository.onboardingCompleted = true
        onboardingWindowRequested = true
    }

    func dismissRecoveryNotice() {
        shouldShowRecoveryNotice = false
        settingsRepository.menuBarWasRemoved = false
    }

    func restoreMenuBarItem() {
        isMenuBarItemInserted = true
        shouldShowRecoveryNotice = true
        AppDelegate.shared?.showRecoveryWindow()
    }

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

    func setDashboardVisible(_ visible: Bool) {
        dashboardIsVisible = visible
        if visible, let lastSnapshot {
            latest = lastSnapshot
        }
        Task {
            await coordinator.setDashboardVisible(visible)
            if visible {
                await coordinator.sampleNow()
            }
        }
    }

    func prepareForSleep() {
        Task { await coordinator.prepareForSleep() }
    }

    func resumeAfterWake() {
        Task { await coordinator.resumeAfterWake() }
    }

    func volumeConfigurationChanged() {
        Task { await coordinator.volumeConfigurationChanged() }
    }

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

    func moveModule(_ module: MenuBarModule, offset: Int) {
        guard let index = settings.visibleModules.firstIndex(of: module) else { return }
        let destination = index + offset
        guard settings.visibleModules.indices.contains(destination) else { return }
        settings.visibleModules.swapAt(index, destination)
    }

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

    func openLoginItemSettings() {
        loginItemService.openSystemSettings()
    }

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

    private func applyAppearanceSettings() {
        NSApplication.shared.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    private var localizationLocale: Locale {
        settings.language.locale ?? .current
    }

    private static func isLoginItemEnabled(_ status: LoginItemStatus) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    private func publish(snapshot: SystemSnapshot, history: DashboardHistory) {
        lastSnapshot = snapshot
        if dashboardIsVisible {
            latest = snapshot
            if history != .empty {
                self.history = history
            }
        }
        let nextMenuBarSummary = MenuBarSummary(snapshot: snapshot)
        if nextMenuBarSummary != menuBarSummary {
            menuBarSummary = nextMenuBarSummary
        }
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

    private func isUnavailable<Value: Sendable & Equatable>(
        _ value: MetricValue<Value>
    ) -> Bool {
        if case .unavailable = value { return true }
        return false
    }
}

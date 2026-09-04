import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: AppModel?
    static weak var shared: AppDelegate?

    private var onboardingWindow: NSWindow?
    private var recoveryWindow: NSWindow?
    private var dashboardWindow: NSWindow?
    private weak var settingsWindow: NSWindow?
    private var shouldBringSettingsWindowToFront = false

    /// 保存应用代理的弱引用，供界面动作找到统一窗口管理入口。
    override init() {
        super.init()
        Self.shared = self
    }

    /// 启动后按持久化状态展示首次引导或菜单栏恢复提示。
    func applicationDidFinishLaunching(_ notification: Notification) {
        PulseBarLog.lifecycle.info("PulseBar launched")
        guard let model = Self.model else { return }
        if model.needsOnboarding {
            model.markOnboardingWindowRequested()
            showOnboardingWindow()
        } else if model.shouldShowRecoveryNotice {
            showRecoveryWindow()
        }
    }

    /// 响应 Dock/Finder 的再次打开：恢复被移除的菜单栏项，或按设置展示独立面板。
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if let model = Self.model, !model.isMenuBarItemInserted {
            model.restoreMenuBarItem()
        } else if Self.model?.settings.openBehavior == .showDashboard {
            showDashboardWindow()
        }
        if !flag {
            sender.activate(ignoringOtherApps: true)
        }
        return true
    }

    /// 记录应用正常退出事件，便于区分生命周期与采样问题。
    func applicationWillTerminate(_ notification: Notification) {
        PulseBarLog.lifecycle.info("PulseBar terminating")
    }

    /// 注入当前模型和语言，创建或复用首次使用引导窗口。
    func showOnboardingWindow() {
        guard let model = Self.model else { return }
        let root = AnyView(
            OnboardingView()
                .environmentObject(model)
                .environment(\.locale, model.settings.language.locale ?? .current)
        )
        onboardingWindow = present(
            existing: onboardingWindow,
            title: String(
                localized: "欢迎使用 PulseBar",
                locale: model.settings.language.locale ?? .current
            ),
            size: NSSize(width: 560, height: 460),
            rootView: root
        )
    }

    /// 展示可复用的恢复提示窗口，帮助用户找回菜单栏入口。
    func showRecoveryWindow() {
        guard let model = Self.model else { return }
        let root = AnyView(
            RecoveryView()
                .environmentObject(model)
                .environment(\.locale, model.settings.language.locale ?? .current)
        )
        recoveryWindow = present(
            existing: recoveryWindow,
            title: String(
                localized: "恢复 PulseBar",
                locale: model.settings.language.locale ?? .current
            ),
            size: NSSize(width: 460, height: 300),
            rootView: root
        )
    }

    /// 创建或复用独立监控窗口，注入面板状态、单位及语言设置。
    func showDashboardWindow() {
        guard let model = Self.model else { return }
        let root = AnyView(
            DashboardView()
                .environmentObject(model)
                .environmentObject(model.dashboardPresentation)
                .environment(\.unitSystem, model.settings.unitSystem)
                .environment(\.locale, model.settings.language.locale ?? .current)
        )
        dashboardWindow = present(
            existing: dashboardWindow,
            title: "PulseBar",
            size: NSSize(width: 420, height: 650),
            rootView: root
        )
    }

    /// 接收 SwiftUI 设置视图所属的真实 NSWindow，并兑现首次创建时挂起的置前请求。
    func registerSettingsWindow(_ window: NSWindow) {
        settingsWindow = window
        guard shouldBringSettingsWindowToFront else { return }
        shouldBringSettingsWindowToFront = false
        bringSettingsWindowToFront()
    }

    /// 优先激活已有设置窗口；不存在时才调用创建闭包，并等待窗口注册后置前。
    func openSettings(createIfNeeded: () -> Void) {
        if bringSettingsWindowToFront() {
            return
        }

        shouldBringSettingsWindowToFront = true
        createIfNeeded()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// 激活应用、还原最小化状态并置前设置窗口；未注册窗口时返回 false。
    @discardableResult
    private func bringSettingsWindowToFront() -> Bool {
        guard let settingsWindow else { return false }
        let application = NSApplication.shared
        application.activate(ignoringOtherApps: true)
        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }
        settingsWindow.makeKeyAndOrderFront(nil)
        return true
    }

    /// 统一创建或复用辅助窗口；复用时替换内容，关闭后保留窗口供下次展示。
    private func present(
        existing: NSWindow?,
        title: String,
        size: NSSize,
        rootView: AnyView
    ) -> NSWindow {
        let window: NSWindow
        if let existing {
            existing.contentViewController = NSHostingController(rootView: rootView)
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.title = title
            window.contentViewController = NSHostingController(rootView: rootView)
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return window
    }
}

import AppKit
import SwiftUI

struct AppMenuBarLabel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var presentation: MenuBarPresentationState

    /// 菜单栏入口同时承接启动和系统事件；采样逻辑由模型转交协调器，视图只订阅摘要。
    var body: some View {
        MenuBarLabelView(
            summary: presentation.summary,
            preferences: model.menuBarPreferences
        )
        .task {
            await model.startMonitoring()
            if model.needsOnboarding {
                model.markOnboardingWindowRequested()
                AppDelegate.shared?.showOnboardingWindow()
            } else if model.shouldShowRecoveryNotice {
                AppDelegate.shared?.showRecoveryWindow()
            }
        }
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
}

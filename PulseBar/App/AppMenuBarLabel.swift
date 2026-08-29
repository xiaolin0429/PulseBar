import AppKit
import SwiftUI

struct AppMenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        MenuBarLabelView(
            summary: model.menuBarSummary,
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

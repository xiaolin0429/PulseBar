import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var isMenuBarItemInserted = true
    @Published private(set) var menuBarSummary = MenuBarSummary.preview
    @Published var menuBarPreferences = MenuBarPreferences()
    @Published private(set) var monitoringState: MonitoringState = .preview

    enum MonitoringState: Equatable {
        case preview
        case monitoring
        case paused
        case partiallyUnavailable
    }

    func togglePaused() {
        monitoringState = monitoringState == .paused ? .preview : .paused
    }
}

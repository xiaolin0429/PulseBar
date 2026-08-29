import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var isMenuBarItemInserted = true
    @Published private(set) var menuBarSummary = MenuBarSummary.unavailable
    @Published var menuBarPreferences = MenuBarPreferences()
    @Published private(set) var monitoringState: MonitoringState = .monitoring
    @Published private(set) var latest: SystemSnapshot?
    @Published private(set) var history = DashboardHistory.empty

    private let coordinator: SamplingCoordinator
    private var hasStarted = false

    enum MonitoringState: Equatable {
        case monitoring
        case paused
        case partiallyUnavailable
    }

    init(coordinator: SamplingCoordinator = SamplingCoordinator()) {
        self.coordinator = coordinator
    }

    func startMonitoring() async {
        guard !hasStarted else { return }
        hasStarted = true
        await coordinator.start { [weak self] snapshot, history in
            self?.publish(snapshot: snapshot, history: history)
        }
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
        Task { await coordinator.setDashboardVisible(visible) }
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

    private func publish(snapshot: SystemSnapshot, history: DashboardHistory) {
        latest = snapshot
        if history != .empty {
            self.history = history
        }
        menuBarSummary = MenuBarSummary(snapshot: snapshot)
        let hasFailure = [
            isUnavailable(snapshot.cpu),
            isUnavailable(snapshot.memory),
            isUnavailable(snapshot.disk),
            isUnavailable(snapshot.network)
        ].contains(true)
        monitoringState = hasFailure ? .partiallyUnavailable : .monitoring
    }

    private func isUnavailable<Value: Sendable & Equatable>(
        _ value: MetricValue<Value>
    ) -> Bool {
        if case .unavailable = value { return true }
        return false
    }
}

import Combine

@MainActor
final class MenuBarPresentationState: ObservableObject {
    @Published private(set) var summary = MenuBarSummary.unavailable

    func publish(_ summary: MenuBarSummary) {
        guard self.summary != summary else { return }
        self.summary = summary
    }
}

@MainActor
final class DashboardPresentationState: ObservableObject {
    struct Content: Equatable {
        var snapshot: SystemSnapshot?
        var history = DashboardHistory.empty
    }

    @Published private(set) var content = Content()

    var latest: SystemSnapshot? { content.snapshot }
    var history: DashboardHistory { content.history }

    func publish(snapshot: SystemSnapshot, history: DashboardHistory) {
        let next = Content(snapshot: snapshot, history: history)
        guard content != next else { return }
        content = next
    }

    func show(snapshot: SystemSnapshot?) {
        guard let snapshot, content.snapshot != snapshot else { return }
        content = Content(snapshot: snapshot, history: content.history)
    }
}

import Combine

@MainActor
final class MenuBarPresentationState: ObservableObject {
    @Published private(set) var summary = MenuBarSummary.unavailable

    /// 仅在摘要变化时触发菜单栏重绘，隔离面板历史与高频细节更新。
    func publish(_ summary: MenuBarSummary) {
        guard self.summary != summary else { return }
        self.summary = summary
    }
}

@MainActor
final class DashboardPresentationState: ObservableObject {
    struct Content: Equatable {
        var isVisible = false
        var snapshot: SystemSnapshot?
        var history = DashboardHistory.empty
    }

    @Published private(set) var content = Content()

    var latest: SystemSnapshot? { content.snapshot }
    var history: DashboardHistory { content.history }
    var isVisible: Bool { content.isVisible }

    /// 一次发布可见性、快照和历史，避免分别更新造成额外刷新或短暂不一致。
    func publish(snapshot: SystemSnapshot, history: DashboardHistory) {
        let next = Content(isVisible: true, snapshot: snapshot, history: history)
        guard content != next else { return }
        content = next
    }

    /// 打开面板时先提供最近快照，沿用当前历史等待下一轮采样。
    func show(snapshot: SystemSnapshot?) {
        let next = Content(
            isVisible: true,
            snapshot: snapshot ?? content.snapshot,
            history: content.history
        )
        guard content != next else { return }
        content = next
    }

    /// 一次清空可见标志、快照和绘图数组，使隐藏面板不再持有展示数据。
    func hide() {
        let emptyContent = Content()
        guard content != emptyContent else { return }
        content = emptyContent
    }
}

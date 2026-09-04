import Foundation

public enum RefreshPolicy: String, CaseIterable, Codable, Sendable {
    case adaptive
    case everySecond
    case everyTwoSeconds
    case everyFiveSeconds

    public func interval(dashboardVisible: Bool) -> Duration {
        switch self {
        case .adaptive: dashboardVisible ? .seconds(1) : .seconds(2)
        case .everySecond: .seconds(1)
        case .everyTwoSeconds: .seconds(2)
        case .everyFiveSeconds: .seconds(5)
        }
    }
}

public enum HistoryWindow: Int, CaseIterable, Codable, Sendable {
    case seconds60 = 60
    case seconds120 = 120
    case seconds300 = 300

    public var duration: Duration { .seconds(rawValue) }
}

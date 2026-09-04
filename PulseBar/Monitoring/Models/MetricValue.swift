import Foundation

public enum MetricValue<Value: Sendable & Equatable>: Sendable, Equatable {
    case available(Value)
    case warmingUp
    case unavailable(MetricFailure)
    case stale(Value, age: Duration)

    /// 提取可展示的值，包括 stale 旧值；需要判断新鲜度时必须显式匹配枚举状态。
    public var availableValue: Value? {
        switch self {
        case let .available(value), let .stale(value, _): value
        case .warmingUp, .unavailable: nil
        }
    }
}

public struct MetricFailure: Sendable, Equatable, Error {
    public let code: Code
    public let userMessageKey: String
    public let debugContext: String?

    public enum Code: String, Sendable {
        case permissionDenied
        case unsupported
        case systemCallFailed
        case invalidCounter
        case sourceMissing
    }

    public init(code: Code, userMessageKey: String, debugContext: String? = nil) {
        self.code = code
        self.userMessageKey = userMessageKey
        self.debugContext = debugContext
    }

    static func reading(_ error: Error, source: String) -> MetricFailure {
        MetricFailure(
            code: .systemCallFailed,
            userMessageKey: "metric.error.temporarilyUnavailable",
            debugContext: "\(source): \(error)"
        )
    }
}

import Foundation

public enum MetricValue<Value: Sendable & Equatable>: Sendable, Equatable {
    case available(Value)
    case warmingUp
    case unavailable(MetricFailure)
    case stale(Value, age: Duration)

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

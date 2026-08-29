import Foundation

struct AppEnvironment: Sendable {
    var now: @Sendable () -> Date

    static let live = AppEnvironment(now: Date.init)
}

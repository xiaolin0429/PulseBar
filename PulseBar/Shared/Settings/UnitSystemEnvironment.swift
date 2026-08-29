import SwiftUI

private struct UnitSystemEnvironmentKey: EnvironmentKey {
    static let defaultValue: UnitSystem = .mixedDefault
}

extension EnvironmentValues {
    var unitSystem: UnitSystem {
        get { self[UnitSystemEnvironmentKey.self] }
        set { self[UnitSystemEnvironmentKey.self] = newValue }
    }
}


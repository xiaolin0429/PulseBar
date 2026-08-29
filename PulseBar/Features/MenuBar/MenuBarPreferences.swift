import Foundation

enum MenuBarModule: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu
    case memory
    case disk
    case network

    var id: String { rawValue }
}

enum MenuBarPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case compact
    case standard
    case complete

    var id: String { rawValue }
}

struct MenuBarPreferences: Equatable, Sendable {
    var preset: MenuBarPreset = .standard
    var visibleModules: [MenuBarModule] = [.cpu, .memory, .network]
    var showDecimals = false
}

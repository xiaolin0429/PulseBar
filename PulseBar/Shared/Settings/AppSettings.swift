import Foundation

public enum MenuBarModule: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu
    case memory
    case disk
    case network

    public var id: String { rawValue }
}

public enum MenuBarPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case compact
    case standard
    case complete

    public var id: String { rawValue }
}

public enum UnitSystem: String, CaseIterable, Codable, Sendable, Identifiable {
    case mixedDefault
    case decimal
    case binary

    public var id: String { rawValue }
}

public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case simplifiedChinese
    case english

    public var id: String { rawValue }

    public var locale: Locale? {
        switch self {
        case .system: nil
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }
}

public enum AppOpenBehavior: String, CaseIterable, Codable, Sendable, Identifiable {
    case menuBarOnly
    case showDashboard

    public var id: String { rawValue }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var launchAtLogin = false
    public var refreshPolicy: RefreshPolicy = .adaptive
    public var historyWindow: HistoryWindow = .seconds60
    public var unitSystem: UnitSystem = .mixedDefault
    public var menuBarPreset: MenuBarPreset = .standard
    public var visibleModules: [MenuBarModule] = [.cpu, .memory, .network]
    public var showDecimals = false
    public var language: AppLanguage = .system
    public var showDockIcon = false
    public var openBehavior: AppOpenBehavior = .menuBarOnly

    public init() {}

    public func normalized() -> AppSettings {
        var result = self
        result.schemaVersion = 1
        var seen: Set<MenuBarModule> = []
        result.visibleModules = visibleModules.filter { seen.insert($0).inserted }
        if result.visibleModules.isEmpty {
            result.visibleModules = [.cpu]
        }
        return result
    }
}


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
    public var schemaVersion = 2
    public var launchAtLogin = false
    public var refreshPolicy: RefreshPolicy = .adaptive
    public var historyWindow: HistoryWindow = .seconds60
    public var unitSystem: UnitSystem = .mixedDefault
    public var menuBarPreset: MenuBarPreset = .standard
    public var visibleModules: [MenuBarModule] = [.cpu, .memory, .network]
    public var moduleOrder: [MenuBarModule]? = MenuBarModule.allCases
    public var showDecimals = false
    public var language: AppLanguage = .system
    public var showDockIcon = false
    public var openBehavior: AppOpenBehavior = .menuBarOnly

    public init() {}

    /// 去重并补齐所有模块；旧设置没有全量排序时，以原可见顺序作为兼容起点。
    public var orderedModules: [MenuBarModule] {
        var seen: Set<MenuBarModule> = []
        let preferredOrder = moduleOrder ?? visibleModules
        var result = preferredOrder.filter { seen.insert($0).inserted }
        result.append(contentsOf: MenuBarModule.allCases.filter { seen.insert($0).inserted })
        return result
    }

    public mutating func moveModule(_ module: MenuBarModule, to target: MenuBarModule) {
        var order = orderedModules
        guard let sourceIndex = order.firstIndex(of: module),
              let targetIndex = order.firstIndex(of: target),
              sourceIndex != targetIndex else { return }

        let movedModule = order.remove(at: sourceIndex)
        order.insert(movedModule, at: targetIndex)
        applyModuleOrder(order)
    }

    public mutating func moveModule(_ module: MenuBarModule, offset: Int) {
        let order = orderedModules
        guard let sourceIndex = order.firstIndex(of: module) else { return }
        let targetIndex = sourceIndex + offset
        guard order.indices.contains(targetIndex) else { return }
        moveModule(module, to: order[targetIndex])
    }

    /// 升级设置版本、补全并去重模块顺序，按该顺序整理可见项且至少保留一个。
    public func normalized() -> AppSettings {
        var result = self
        result.schemaVersion = 2
        let order = orderedModules
        result.moduleOrder = order
        let visibleSet = Set(visibleModules)
        result.visibleModules = order.filter { visibleSet.contains($0) }
        if result.visibleModules.isEmpty {
            result.visibleModules = [order.first ?? .cpu]
        }
        return result
    }

    private mutating func applyModuleOrder(_ order: [MenuBarModule]) {
        moduleOrder = order
        let visibleSet = Set(visibleModules)
        visibleModules = order.filter { visibleSet.contains($0) }
    }
}

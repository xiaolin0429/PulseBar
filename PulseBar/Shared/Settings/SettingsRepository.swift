import Foundation

public struct SettingsRepository {
    public static let settingsKey = "settings.schema.v1"
    public static let onboardingCompletedKey = "onboarding.completed.v1"
    public static let menuBarRemovedKey = "menuBar.removed.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 注入 UserDefaults 存储域；测试可使用独立域，不污染真实用户偏好。
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 读取并解码设置后规范化；缺失或损坏的数据回退到安全默认值。
    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let decoded = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded.normalized()
    }

    /// 规范化设置后编码保存；编码失败时保持现有持久化内容。
    public func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings.normalized()) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    public var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Self.onboardingCompletedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.onboardingCompletedKey) }
    }

    public var menuBarWasRemoved: Bool {
        get { defaults.bool(forKey: Self.menuBarRemovedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.menuBarRemovedKey) }
    }

    /// 仅重置应用设置，保留独立存储的引导完成和菜单栏移除标记。
    public func resetSettings() -> AppSettings {
        let defaultsValue = AppSettings()
        save(defaultsValue)
        return defaultsValue
    }
}

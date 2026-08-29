import Foundation

public struct SettingsRepository {
    public static let settingsKey = "settings.schema.v1"
    public static let onboardingCompletedKey = "onboarding.completed.v1"
    public static let menuBarRemovedKey = "menuBar.removed.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let decoded = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded.normalized()
    }

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

    public func resetSettings() -> AppSettings {
        let defaultsValue = AppSettings()
        save(defaultsValue)
        return defaultsValue
    }
}


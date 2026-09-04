import Foundation
import XCTest
@testable import PulseBarCore

final class SettingsRepositoryTests: XCTestCase {
    func testSettingsRoundTripAndOnboardingFlag() throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var settings = AppSettings()
        settings.menuBarPreset = .complete
        settings.visibleModules = [.network, .cpu]
        settings.moduleOrder = [.network, .cpu, .memory, .disk]
        settings.historyWindow = .seconds300
        settings.unitSystem = .binary
        repository.save(settings)
        repository.onboardingCompleted = true

        XCTAssertEqual(repository.load(), settings)
        XCTAssertTrue(repository.onboardingCompleted)
    }

    func testInvalidEmptyAndDuplicateModulesAreNormalized() throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var settings = AppSettings()
        settings.visibleModules = []
        repository.save(settings)
        XCTAssertEqual(repository.load().visibleModules, [.cpu])

        settings.visibleModules = [.cpu, .cpu, .network]
        repository.save(settings)
        XCTAssertEqual(repository.load().visibleModules, [.cpu, .network])
    }

    func testModuleOrderNormalizesDuplicatesAndMissingModules() {
        var settings = AppSettings()
        settings.visibleModules = [.memory, .network, .cpu]
        settings.moduleOrder = [.network, .network, .cpu]

        let normalized = settings.normalized()

        XCTAssertEqual(normalized.orderedModules, [.network, .cpu, .memory, .disk])
        XCTAssertEqual(normalized.visibleModules, [.network, .cpu, .memory])
    }

    func testMovingModuleUpdatesFullAndVisibleOrder() {
        var settings = AppSettings()

        settings.moveModule(.network, to: .cpu)
        XCTAssertEqual(settings.orderedModules, [.network, .cpu, .memory, .disk])
        XCTAssertEqual(settings.visibleModules, [.network, .cpu, .memory])

        settings.moveModule(.network, offset: 1)
        XCTAssertEqual(settings.orderedModules, [.cpu, .network, .memory, .disk])
        XCTAssertEqual(settings.visibleModules, [.cpu, .network, .memory])
    }

    func testLegacySettingsWithoutModuleOrderPreserveVisibleOrder() throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        let legacySettings: [String: Any] = [
            "schemaVersion": 1,
            "launchAtLogin": false,
            "refreshPolicy": "adaptive",
            "historyWindow": 60,
            "unitSystem": "mixedDefault",
            "menuBarPreset": "standard",
            "visibleModules": ["network", "cpu"],
            "showDecimals": false,
            "language": "system",
            "showDockIcon": false,
            "openBehavior": "menuBarOnly"
        ]
        defaults.set(
            try JSONSerialization.data(withJSONObject: legacySettings),
            forKey: SettingsRepository.settingsKey
        )

        let loaded = repository.load()

        XCTAssertEqual(loaded.schemaVersion, 2)
        XCTAssertEqual(loaded.orderedModules, [.network, .cpu, .memory, .disk])
        XCTAssertEqual(loaded.visibleModules, [.network, .cpu])
    }

    func testCorruptDataFallsBackToSafeDefaults() throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: SettingsRepository.settingsKey)
        XCTAssertEqual(SettingsRepository(defaults: defaults).load(), AppSettings())
    }
}

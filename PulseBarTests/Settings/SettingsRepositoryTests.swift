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

    func testCorruptDataFallsBackToSafeDefaults() throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: SettingsRepository.settingsKey)
        XCTAssertEqual(SettingsRepository(defaults: defaults).load(), AppSettings())
    }
}

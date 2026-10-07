import XCTest
@testable import WordFlow500

@MainActor
final class AppSettingsTests: XCTestCase {
    func testSelectedListAssignmentPersistsWithoutRecursion() {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.selectedList = 42

        XCTAssertEqual(settings.selectedList, 42)
        XCTAssertEqual(defaults.integer(forKey: "settings.selectedList"), 42)
    }

    func testDeletedListSelectionNormalizesToAll() {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(
            defaults: defaults,
            storagePrefix: "profile-a."
        )
        settings.selectedList = 99
        settings.normalizeSelectedList(validListIDs: [1, 2, 3])

        XCTAssertEqual(settings.selectedList, 0)
        XCTAssertEqual(
            defaults.integer(forKey: "profile-a.settings.selectedList"),
            0
        )
    }
}

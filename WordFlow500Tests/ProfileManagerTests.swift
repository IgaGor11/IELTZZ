import XCTest
@testable import WordFlow500

@MainActor
final class ProfileManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProfileManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchCreatesAndPersistsStablePrimaryProfile() {
        let firstManager = ProfileManager(defaults: defaults)

        XCTAssertEqual(firstManager.profiles.count, 1)
        XCTAssertEqual(
            firstManager.selectedProfile.name,
            ProfileManager.primaryProfileName
        )
        let originalID = firstManager.selectedProfileID

        let reopenedManager = ProfileManager(defaults: defaults)

        XCTAssertEqual(reopenedManager.profiles.count, 1)
        XCTAssertEqual(reopenedManager.selectedProfileID, originalID)
        XCTAssertEqual(reopenedManager.selectedProfile.id, originalID)
    }

    func testCRUDNormalizesNamesAndPreventsInvalidOperations() {
        let manager = ProfileManager(defaults: defaults)
        let primaryID = manager.selectedProfileID

        XCTAssertNil(manager.create(name: " \n\t "))
        let family = manager.create(name: "  Семейный \n  профиль  ")
        XCTAssertEqual(family?.name, "Семейный профиль")
        XCTAssertNil(manager.create(name: "семейный профиль"))
        XCTAssertNil(manager.create(name: "СЕМЕЙНЫЙ ПРОФИЛЬ"))

        guard let family else {
            return XCTFail("A valid profile should be created")
        }

        XCTAssertTrue(manager.rename(id: primaryID, to: "  Мой   профиль "))
        XCTAssertEqual(
            manager.profiles.first { $0.id == primaryID }?.name,
            "Мой профиль"
        )
        XCTAssertFalse(manager.rename(id: primaryID, to: family.name))
        XCTAssertFalse(manager.rename(id: UUID(), to: "Неизвестный"))

        XCTAssertTrue(manager.select(id: family.id))
        XCTAssertEqual(manager.selectedProfileID, family.id)
        XCTAssertFalse(manager.select(id: UUID()))

        XCTAssertTrue(manager.delete(id: family.id))
        XCTAssertEqual(manager.selectedProfileID, primaryID)
        XCTAssertEqual(manager.profiles.map(\.id), [primaryID])
        XCTAssertFalse(manager.delete(id: primaryID))
    }

    func testProfilesNamesAndSelectionPersist() {
        let firstManager = ProfileManager(defaults: defaults)
        guard let secondProfile = firstManager.create(name: "Рабочий") else {
            return XCTFail("A valid profile should be created")
        }
        XCTAssertTrue(
            firstManager.rename(id: secondProfile.id, to: "Рабочий профиль")
        )
        XCTAssertTrue(firstManager.select(id: secondProfile.id))

        let reopenedManager = ProfileManager(defaults: defaults)

        XCTAssertEqual(reopenedManager.profiles.count, 2)
        XCTAssertEqual(reopenedManager.selectedProfileID, secondProfile.id)
        XCTAssertEqual(reopenedManager.selectedProfile.name, "Рабочий профиль")
    }

    func testProfileDataKeysAreIsolatedAndDeletionDoesNotEraseData() {
        let manager = ProfileManager(defaults: defaults)
        let primaryID = manager.selectedProfileID
        guard let secondProfile = manager.create(name: "Второй") else {
            return XCTFail("A valid profile should be created")
        }

        let primaryWordsKey = ProfileManager.storageKey(
            "vocabulary.words.v1",
            for: primaryID
        )
        let primaryDrawingKey = ProfileManager.storageKey(
            "vocabulary.drawing.1",
            for: primaryID
        )
        let secondWordsKey = ProfileManager.storageKey(
            "vocabulary.words.v1",
            for: secondProfile.id
        )
        let globalKey = "unrelated.global.value"

        defaults.set(Data([1]), forKey: primaryWordsKey)
        defaults.set(Data([2]), forKey: primaryDrawingKey)
        defaults.set(Data([3]), forKey: secondWordsKey)
        defaults.set("keep", forKey: globalKey)

        XCTAssertEqual(
            manager.profileDataKeys(for: primaryID),
            [primaryDrawingKey, primaryWordsKey].sorted()
        )
        XCTAssertEqual(
            manager.profileDataKeys(for: secondProfile.id),
            [secondWordsKey]
        )
        XCTAssertTrue(
            ProfileManager.knownProfileKeys(for: primaryID)
                .allSatisfy { $0.hasPrefix(ProfileManager.storagePrefix(for: primaryID)) }
        )

        XCTAssertTrue(manager.delete(id: primaryID))
        XCTAssertEqual(defaults.data(forKey: primaryWordsKey), Data([1]))
        XCTAssertEqual(defaults.data(forKey: primaryDrawingKey), Data([2]))
        XCTAssertEqual(defaults.data(forKey: secondWordsKey), Data([3]))
        XCTAssertEqual(defaults.string(forKey: globalKey), "keep")
        XCTAssertEqual(
            manager.profileDataKeys(for: primaryID),
            [primaryDrawingKey, primaryWordsKey].sorted()
        )
    }
}

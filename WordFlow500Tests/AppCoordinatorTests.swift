import XCTest
@testable import WordFlow500

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func testProfilesKeepWordsProgressAndSettingsIsolated() throws {
        let suiteName = "AppCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = AppCoordinator(defaults: defaults)
        let primaryID = coordinator.activeProfile.id
        coordinator.store.grade(id: 1, isCorrect: true)
        coordinator.settings.selectedList = 3
        coordinator.store.updateTranslation(
            "мой первый перевод",
            example: "Primary example.",
            for: 1
        )

        let second = try XCTUnwrap(
            coordinator.createProfile(named: "Второй")
        )
        XCTAssertEqual(coordinator.activeProfile.id, second.id)
        XCTAssertEqual(coordinator.store.word(id: 1)?.level, 0)
        XCTAssertEqual(
            coordinator.store.word(id: 1)?.translation,
            "достигать"
        )
        XCTAssertEqual(coordinator.settings.selectedList, 0)

        coordinator.store.grade(id: 1, isCorrect: false)
        coordinator.settings.selectedList = 5

        XCTAssertTrue(coordinator.selectProfile(id: primaryID))
        XCTAssertEqual(coordinator.store.word(id: 1)?.level, 1)
        XCTAssertEqual(
            coordinator.store.word(id: 1)?.translation,
            "мой первый перевод"
        )
        XCTAssertEqual(coordinator.settings.selectedList, 3)
    }

    func testLegacyDataMigratesIntoPrimaryProfileOnce() {
        let suiteName = "AppCoordinatorLegacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyStore = VocabularyStore(defaults: defaults)
        legacyStore.updateTranslation(
            "старый перевод",
            example: "Legacy example.",
            for: 1
        )
        defaults.set(4, forKey: "settings.selectedList")

        let coordinator = AppCoordinator(defaults: defaults)

        XCTAssertEqual(
            coordinator.store.word(id: 1)?.translation,
            "старый перевод"
        )
        XCTAssertEqual(coordinator.settings.selectedList, 4)
        XCTAssertTrue(defaults.bool(forKey: "wordflow.legacyMigration.v1"))
    }

    func testNotificationPayloadSwitchesProfileAndPreparesStudySession() throws {
        let suiteName = "AppCoordinatorNotificationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = AppCoordinator(
            defaults: defaults,
            installsNotificationDelegate: false
        )
        let primaryID = coordinator.activeProfile.id
        _ = try XCTUnwrap(coordinator.createProfile(named: "Второй"))
        coordinator.selectedTab = .statistics

        let handled = coordinator.handleNotificationPayload(
            StudyNotificationPayload(
                profileID: primaryID,
                listID: 3,
                onlyDifficult: true,
                targetCount: 12
            )
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(coordinator.activeProfile.id, primaryID)
        XCTAssertEqual(coordinator.settings.selectedList, 3)
        XCTAssertTrue(coordinator.settings.onlyDifficult)
        XCTAssertEqual(coordinator.selectedTab, .study)
        XCTAssertEqual(
            coordinator.pendingStudySessionRequest?.targetCount,
            12
        )
        XCTAssertEqual(
            coordinator.takePendingStudySessionRequest()?.targetCount,
            12
        )
        XCTAssertNil(coordinator.pendingStudySessionRequest)
    }

    func testNotificationPayloadRejectsUnknownProfileAndRepairsList() {
        let suiteName = "AppCoordinatorNotificationRepairTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = AppCoordinator(
            defaults: defaults,
            installsNotificationDelegate: false
        )
        let activeID = coordinator.activeProfile.id
        coordinator.settings.selectedList = 2

        XCTAssertFalse(
            coordinator.handleNotificationPayload(
                StudyNotificationPayload(
                    profileID: UUID(),
                    listID: 1,
                    onlyDifficult: true,
                    targetCount: 5
                )
            )
        )
        XCTAssertEqual(coordinator.settings.selectedList, 2)
        XCTAssertNil(coordinator.pendingStudySessionRequest)

        XCTAssertTrue(
            coordinator.handleNotificationPayload(
                StudyNotificationPayload(
                    profileID: activeID,
                    listID: 999,
                    onlyDifficult: false,
                    targetCount: 5
                )
            )
        )
        XCTAssertEqual(coordinator.settings.selectedList, 0)
    }

    func testDeletingActiveProfileLeavesItsNamespaceEmpty() throws {
        let suiteName = "AppCoordinatorDeletionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = AppCoordinator(
            defaults: defaults,
            installsNotificationDelegate: false
        )
        let deletedProfile = try XCTUnwrap(
            coordinator.createProfile(named: "Удаляемый")
        )
        coordinator.store.updateTranslation(
            "личный перевод",
            example: "Private example.",
            for: 1
        )
        coordinator.store.grade(id: 1, isCorrect: true)
        let deletedPrefix = ProfileManager.storagePrefix(
            for: deletedProfile.id
        )

        XCTAssertTrue(coordinator.deleteProfile(id: deletedProfile.id))

        let remainingKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(deletedPrefix)
        }
        XCTAssertTrue(remainingKeys.isEmpty, "\(remainingKeys)")
        XCTAssertEqual(
            defaults.string(
                forKey: ReminderStore.invalidationKey(
                    for: deletedProfile.id.uuidString
                )
            ),
            deletedProfile.id.uuidString
        )
        XCTAssertNil(
            defaults.data(
                forKey: ReminderStore.storageKey(
                    for: deletedProfile.id.uuidString
                )
            )
        )
        XCTAssertNotEqual(coordinator.activeProfile.id, deletedProfile.id)
    }

    func testStartupRepairsInterruptedDeletedProfileReminderCleanup() {
        let suiteName = "AppCoordinatorCleanupTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let deletedProfileID = UUID().uuidString
        ReminderStore.markProfileDeleted(
            profileID: deletedProfileID,
            defaults: defaults
        )
        let staleStorageKey = ReminderStore.storageKey(
            for: deletedProfileID
        )
        defaults.set(Data([1, 2, 3]), forKey: staleStorageKey)

        _ = AppCoordinator(
            defaults: defaults,
            installsNotificationDelegate: false
        )

        XCTAssertNil(defaults.data(forKey: staleStorageKey))
        XCTAssertTrue(
            ReminderStore.deletedProfileIDs(defaults: defaults)
                .contains(deletedProfileID)
        )
    }
}

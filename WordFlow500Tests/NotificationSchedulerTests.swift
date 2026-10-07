import XCTest
@testable import WordFlow500

final class NotificationSchedulerTests: XCTestCase {
    func testBuilderCreatesOneRepeatingDescriptorPerWeekday() {
        let reminderID = UUID(
            uuidString: "11111111-2222-3333-4444-555555555555"
        )!
        let reminder = StudyReminder(
            id: reminderID,
            title: "Утренняя практика",
            enabled: true,
            hour: 8,
            minute: 25,
            weekdays: [2, 4, 6],
            listID: 3,
            onlyDifficult: true,
            targetCount: 15
        )

        let descriptors = StudyReminderRequestBuilder.makeDescriptors(
            profileID: "student-a",
            reminders: [reminder]
        )

        XCTAssertEqual(descriptors.count, 3)
        XCTAssertEqual(
            descriptors.compactMap(\.dateComponents.weekday),
            [2, 4, 6]
        )
        XCTAssertTrue(
            descriptors.allSatisfy {
                $0.dateComponents.hour == 8
                    && $0.dateComponents.minute == 25
            }
        )
        XCTAssertTrue(
            descriptors.allSatisfy {
                $0.identifier.contains(reminderID.uuidString.lowercased())
            }
        )
        XCTAssertTrue(
            descriptors.allSatisfy {
                $0.body.contains("15 слов из списка 3")
                    && $0.body.contains("сложные")
            }
        )
        XCTAssertEqual(descriptors.first?.userInfo["profileID"], "student-a")
        XCTAssertEqual(descriptors.first?.userInfo["targetCount"], "15")
    }

    func testBuilderSkipsDisabledRemindersAndInvalidWeekdays() {
        let disabled = StudyReminder(
            title: "Выключено",
            enabled: false,
            weekdays: [1, 2, 3]
        )
        var active = StudyReminder(
            title: "Воскресенье",
            enabled: true,
            weekdays: [1]
        )
        active.weekdays = [0, 1, 8]

        let descriptors = StudyReminderRequestBuilder.makeDescriptors(
            profileID: "profile",
            reminders: [disabled, active]
        )

        XCTAssertEqual(descriptors.count, 1)
        XCTAssertEqual(descriptors.first?.dateComponents.weekday, 1)
    }

    func testIdentifiersAreIsolatedByProfile() {
        let reminder = StudyReminder(
            enabled: true,
            weekdays: [2]
        )
        let firstProfile = "user"
        let secondProfile = "user.extra"
        let firstPrefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: firstProfile)
        let secondPrefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: secondProfile)

        let firstID = StudyReminderRequestBuilder.makeDescriptors(
            profileID: firstProfile,
            reminders: [reminder]
        ).first?.identifier
        let secondID = StudyReminderRequestBuilder.makeDescriptors(
            profileID: secondProfile,
            reminders: [reminder]
        ).first?.identifier

        XCTAssertNotEqual(firstPrefix, secondPrefix)
        XCTAssertFalse(secondPrefix.hasPrefix(firstPrefix + "."))
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertTrue(firstID?.hasPrefix(firstPrefix + ".") == true)
        XCTAssertTrue(secondID?.hasPrefix(secondPrefix + ".") == true)
    }

    func testBuilderNormalizesValuesAndUsesRussianWordForms() {
        let oneWord = StudyReminder(
            title: " ",
            enabled: true,
            hour: 99,
            minute: -5,
            weekdays: [3],
            listID: 0,
            targetCount: 21
        )
        let fourteenWords = StudyReminder(
            enabled: true,
            weekdays: [5],
            listID: 2,
            targetCount: 14
        )

        let descriptors = StudyReminderRequestBuilder.makeDescriptors(
            profileID: "",
            reminders: [oneWord, fourteenWords]
        )

        XCTAssertEqual(descriptors.count, 2)
        XCTAssertEqual(descriptors[0].title, "Время повторить слова")
        XCTAssertEqual(descriptors[0].dateComponents.hour, 23)
        XCTAssertEqual(descriptors[0].dateComponents.minute, 0)
        XCTAssertTrue(
            descriptors[0].body.contains(
                "21 слово из всех списков"
            )
        )
        XCTAssertTrue(
            descriptors[1].body.contains(
                "14 слов из списка 2"
            )
        )
    }

    func testStudyReminderCodableRoundTripPreservesSchedule() throws {
        let reminder = StudyReminder(
            title: "После обеда",
            enabled: true,
            hour: 14,
            minute: 10,
            weekdays: [1, 3, 7],
            listID: nil,
            onlyDifficult: true,
            targetCount: 42
        )

        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(
            StudyReminder.self,
            from: data
        )

        XCTAssertEqual(decoded, reminder)
    }

    func testReconciliationPlanKeepsOtherProfilesAndFindsOnlyStaleProfileIDs()
        throws
    {
        let profileID = "student-a"
        let otherProfileID = "student-b"
        let prefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: profileID) + "."
        let otherPrefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: otherProfileID) + "."
        let kept = prefix + "kept"
        let stale = prefix + "stale"
        let other = otherPrefix + "other"
        let added = prefix + "added"

        let plan = try StudyReminderRequestPlanner.makePlan(
            profileID: profileID,
            pendingIdentifiers: [kept, stale, other],
            desiredIdentifiers: [kept, added],
            maximumPendingRequestCount: 6
        )

        XCTAssertEqual(plan.desiredIdentifiers, [kept, added])
        XCTAssertEqual(plan.staleIdentifiers, [stale])
        XCTAssertEqual(plan.projectedPendingRequestCount, 4)
        XCTAssertFalse(plan.staleIdentifiers.contains(other))
    }

    func testReconciliationPlanRejectsUnsafeTemporaryRequestCount() {
        let profileID = "student"
        let prefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: profileID) + "."
        let kept = prefix + "kept"
        let stale = prefix + "stale"

        XCTAssertThrowsError(
            try StudyReminderRequestPlanner.makePlan(
                profileID: profileID,
                pendingIdentifiers: [kept, stale, "other.1", "other.2"],
                desiredIdentifiers: [kept, prefix + "new"],
                maximumPendingRequestCount: 4
            )
        ) { error in
            guard
                let schedulerError = error as? NotificationSchedulerError
            else {
                return XCTFail("Получена ошибка другого типа: \(error)")
            }

            switch schedulerError {
            case .requestLimitExceeded(
                let requested,
                let available,
                let maximum
            ):
                XCTAssertEqual(requested, 2)
                XCTAssertEqual(available, 1)
                XCTAssertEqual(maximum, 4)
                XCTAssertTrue(
                    schedulerError.localizedDescription.contains(
                        "Уменьшите число выбранных дней"
                    )
                )
            default:
                XCTFail("Ожидалась ошибка лимита, получена \(schedulerError)")
            }
        }
    }

    func testListReferenceNormalizerClearsOnlyInvalidLists() {
        let allLists = StudyReminder(title: "Все", listID: 0)
        let noList = StudyReminder(title: "Без списка", listID: nil)
        let valid = StudyReminder(title: "Список 2", listID: 2)
        let removed = StudyReminder(title: "Удалённый", listID: 9)
        let invalid = StudyReminder(title: "Некорректный", listID: -1)

        let result = ReminderListReferenceNormalizer.normalize(
            [allLists, noList, valid, removed, invalid],
            validListIDs: [1, 2, 3]
        )

        XCTAssertEqual(result.changedCount, 2)
        XCTAssertEqual(result.reminders[0].listID, 0)
        XCTAssertNil(result.reminders[1].listID)
        XCTAssertEqual(result.reminders[2].listID, 2)
        XCTAssertNil(result.reminders[3].listID)
        XCTAssertNil(result.reminders[4].listID)
    }

    @MainActor
    func testInvalidatedReminderStoreCannotRecreateDeletedProfileData()
        async
    {
        let suiteName = "ReminderInvalidationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let profileID = UUID().uuidString
        let store = ReminderStore(
            profileID: profileID,
            defaults: defaults
        )
        store.invalidate()

        let result = await store.save(
            StudyReminder(title: "Не должно сохраниться")
        )

        XCTAssertEqual(
            result,
            .savedWithWarning(
                "Профиль удалён, напоминание не сохранено."
            )
        )
        XCTAssertNil(
            defaults.data(
                forKey: ReminderStore.storageKey(for: profileID)
            )
        )
        XCTAssertEqual(
            defaults.string(
                forKey: ReminderStore.invalidationKey(
                    for: profileID
                )
            ),
            profileID
        )
        XCTAssertTrue(
            ReminderStore.deletedProfileIDs(defaults: defaults)
                .contains(profileID)
        )
    }
}

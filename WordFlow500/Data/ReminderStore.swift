import Foundation
import Observation

enum ReminderSaveResult: Equatable, Sendable {
    case saved
    case savedDisabled(StudyNotificationAuthorizationStatus)
    case savedWithWarning(String)
}

struct ReminderListReferenceNormalizationResult: Equatable, Sendable {
    let reminders: [StudyReminder]
    let changedCount: Int
}

enum ReminderListReferenceNormalizer {
    static func normalize(
        _ reminders: [StudyReminder],
        validListIDs: Set<Int>
    ) -> ReminderListReferenceNormalizationResult {
        let validPositiveListIDs = Set(validListIDs.filter { $0 > 0 })
        var normalized = reminders
        var changedCount = 0

        for index in normalized.indices {
            guard let listID = normalized[index].listID else { continue }
            guard listID != 0 else { continue }
            guard
                listID > 0,
                validPositiveListIDs.contains(listID)
            else {
                normalized[index].listID = nil
                changedCount += 1
                continue
            }
        }

        return ReminderListReferenceNormalizationResult(
            reminders: normalized,
            changedCount: changedCount
        )
    }
}

@MainActor
@Observable
final class ReminderStore {
    private static let invalidationKeyPrefix =
        "studyReminders.deletedProfile.v1."

    let profileID: String

    private(set) var reminders: [StudyReminder]
    private(set) var authorizationStatus: StudyNotificationAuthorizationStatus
    private(set) var scheduledRequestCount = 0
    private(set) var isWorking = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let scheduler: NotificationScheduler
    @ObservationIgnored private let encoder: JSONEncoder
    @ObservationIgnored private let decoder: JSONDecoder
    @ObservationIgnored private let storageKey: String
    @ObservationIgnored private var invalidated = false

    init(
        profileID: String,
        defaults: UserDefaults = .standard,
        scheduler: NotificationScheduler? = nil
    ) {
        self.profileID = profileID
        self.defaults = defaults
        self.scheduler = scheduler ?? NotificationScheduler()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        storageKey = Self.storageKey(for: profileID)
        authorizationStatus = .notDetermined

        if
            let data = defaults.data(forKey: storageKey),
            let stored = try? decoder.decode([StudyReminder].self, from: data)
        {
            reminders = Self.uniqueNormalized(stored)
        } else {
            reminders = []
        }
    }

    static func storageKey(for profileID: String) -> String {
        "studyReminders.v1."
            + StudyReminderRequestBuilder.profileToken(for: profileID)
    }

    static func invalidationKey(for profileID: String) -> String {
        invalidationKeyPrefix
            + StudyReminderRequestBuilder.profileToken(for: profileID)
    }

    static func markProfileDeleted(
        profileID: String,
        defaults: UserDefaults
    ) {
        defaults.set(
            profileID,
            forKey: invalidationKey(for: profileID)
        )
        defaults.removeObject(forKey: storageKey(for: profileID))
    }

    static func deletedProfileIDs(defaults: UserDefaults) -> [String] {
        let keys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(invalidationKeyPrefix)
        }
        return Array(
            Set(
                keys.compactMap { key in
                    if let storedID = defaults.string(forKey: key) {
                        return storedID
                    }
                    return profileID(
                        fromInvalidationKey: key
                    )
                }
            )
        ).sorted()
    }

    func invalidate() {
        invalidated = true
        Self.markProfileDeleted(profileID: profileID, defaults: defaults)
    }

    func finishInvalidation() async {
        invalidate()
        while isWorking {
            await Task.yield()
        }
        await cleanupInvalidatedProfile()
    }

    func refresh() async {
        guard !isProfileInvalidated, !isWorking else {
            if isProfileInvalidated {
                await cleanupInvalidatedProfile()
            }
            return
        }
        isWorking = true
        defer { isWorking = false }

        authorizationStatus = await scheduler.authorizationStatus()
        guard !isProfileInvalidated else {
            await cleanupInvalidatedProfile()
            return
        }
        _ = await synchronizeRequests()
    }

    @discardableResult
    func save(_ reminder: StudyReminder) async -> ReminderSaveResult {
        guard !isProfileInvalidated else {
            await cleanupInvalidatedProfile()
            return .savedWithWarning(
                "Профиль удалён, напоминание не сохранено."
            )
        }
        guard !isWorking else {
            return .savedWithWarning("Дождитесь завершения предыдущей операции.")
        }
        isWorking = true
        defer { isWorking = false }

        var candidate = reminder.normalized()
        let wasEnabled = reminders
            .first(where: { $0.id == candidate.id })?
            .enabled ?? false
        var disabledStatus: StudyNotificationAuthorizationStatus?
        var permissionWarning: String?

        if candidate.enabled && !wasEnabled {
            do {
                let permitted = try await scheduler
                    .requestAuthorizationForEnabling()
                authorizationStatus = await scheduler.authorizationStatus()
                if !permitted {
                    candidate.enabled = false
                    disabledStatus = authorizationStatus
                }
            } catch {
                candidate.enabled = false
                authorizationStatus = await scheduler.authorizationStatus()
                permissionWarning = error.localizedDescription
            }
        }

        guard !isProfileInvalidated else {
            await cleanupInvalidatedProfile()
            return .savedWithWarning(
                "Профиль удалён, напоминание не сохранено."
            )
        }
        upsert(candidate)
        persist()
        let schedulingWarning = await synchronizeRequests()

        if let permissionWarning {
            lastErrorMessage = permissionWarning
            return .savedWithWarning(permissionWarning)
        }
        if let disabledStatus {
            let warning = disabledStatus == .denied
                ? "Напоминание сохранено выключенным. Разрешите уведомления в настройках iOS."
                : "Напоминание сохранено выключенным: разрешение не получено."
            lastErrorMessage = warning
            return .savedDisabled(disabledStatus)
        }
        if let schedulingWarning {
            return .savedWithWarning(schedulingWarning)
        }
        return .saved
    }

    @discardableResult
    func setEnabled(
        _ enabled: Bool,
        reminderID: UUID
    ) async -> ReminderSaveResult {
        guard var reminder = reminders.first(where: { $0.id == reminderID }) else {
            let message = "Напоминание больше не существует."
            lastErrorMessage = message
            return .savedWithWarning(message)
        }
        reminder.enabled = enabled
        return await save(reminder)
    }

    func delete(reminderID: UUID) async {
        await delete(reminderIDs: Set([reminderID]))
    }

    func delete(reminderIDs: Set<UUID>) async {
        guard
            !isProfileInvalidated,
            !reminderIDs.isEmpty,
            !isWorking
        else {
            if isProfileInvalidated {
                await cleanupInvalidatedProfile()
            }
            return
        }
        isWorking = true
        defer { isWorking = false }

        reminders.removeAll { reminderIDs.contains($0.id) }
        persist()
        _ = await synchronizeRequests()
    }

    @discardableResult
    func normalizeListReferences(
        validListIDs: Set<Int>
    ) async -> Int {
        guard !isProfileInvalidated else {
            await cleanupInvalidatedProfile()
            return 0
        }
        guard !isWorking else {
            lastErrorMessage =
                "Не удалось обновить ссылки на списки: выполняется другая операция."
            return 0
        }

        let result = ReminderListReferenceNormalizer.normalize(
            reminders,
            validListIDs: validListIDs
        )
        guard result.changedCount > 0 else { return 0 }

        isWorking = true
        defer { isWorking = false }
        reminders = result.reminders
        persist()
        _ = await synchronizeRequests()
        return result.changedCount
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func upsert(_ reminder: StudyReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
    }

    private func persist() {
        guard !isProfileInvalidated else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? encoder.encode(reminders) else {
            lastErrorMessage = "Не удалось сохранить напоминания."
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func synchronizeRequests() async -> String? {
        guard !isProfileInvalidated else {
            await cleanupInvalidatedProfile()
            return nil
        }
        do {
            let requestCount = try await scheduler.synchronize(
                reminders: reminders,
                profileID: profileID
            )
            guard !isProfileInvalidated else {
                await cleanupInvalidatedProfile()
                return nil
            }
            scheduledRequestCount = requestCount
            authorizationStatus = await scheduler.authorizationStatus()
            guard !isProfileInvalidated else {
                await cleanupInvalidatedProfile()
                return nil
            }
            lastErrorMessage = nil
            return nil
        } catch {
            guard !isProfileInvalidated else {
                await cleanupInvalidatedProfile()
                return nil
            }
            scheduledRequestCount = 0
            authorizationStatus = await scheduler.authorizationStatus()
            let message = error.localizedDescription
            lastErrorMessage = message
            return message
        }
    }

    private var isProfileInvalidated: Bool {
        invalidated
            || defaults.object(
                forKey: Self.invalidationKey(for: profileID)
            ) != nil
    }

    private func cleanupInvalidatedProfile() async {
        invalidated = true
        reminders = []
        scheduledRequestCount = 0
        defaults.removeObject(forKey: storageKey)
        await scheduler.removeAllRequests(profileID: profileID)
    }

    private static func uniqueNormalized(
        _ reminders: [StudyReminder]
    ) -> [StudyReminder] {
        var seen = Set<UUID>()
        return reminders.compactMap { reminder in
            guard seen.insert(reminder.id).inserted else { return nil }
            return reminder.normalized()
        }
    }

    private static func profileID(
        fromInvalidationKey key: String
    ) -> String? {
        guard key.hasPrefix(invalidationKeyPrefix) else {
            return nil
        }
        var token = String(key.dropFirst(invalidationKeyPrefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingCount = (4 - token.count % 4) % 4
        token.append(String(repeating: "=", count: paddingCount))
        guard
            let data = Data(base64Encoded: token),
            let profileID = String(data: data, encoding: .utf8),
            !profileID.isEmpty
        else {
            return nil
        }
        return profileID
    }
}

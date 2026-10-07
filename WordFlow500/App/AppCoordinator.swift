import Foundation
import Observation

enum AppTab: Hashable, Sendable {
    case study
    case words
    case statistics
}

struct StudySessionLaunchRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    let targetCount: Int
}

@MainActor
@Observable
final class AppCoordinator {
    let profiles: ProfileManager
    let speech: SpeechService
    let notificationResponseHandler: NotificationResponseHandler

    private(set) var store: VocabularyStore
    private(set) var settings: AppSettings
    private(set) var reminderStore: ReminderStore
    private(set) var profileRevision = 0
    var selectedTab: AppTab = .study
    private(set) var pendingStudySessionRequest: StudySessionLaunchRequest?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var reminderNormalizationTask:
        Task<Void, Never>?
    @ObservationIgnored private var knownReminderStores:
        [String: ReminderStore] = [:]

    init(
        defaults: UserDefaults = .standard,
        isUITesting: Bool = false,
        installsNotificationDelegate: Bool = true
    ) {
        self.defaults = defaults
        profiles = ProfileManager(defaults: defaults)
        speech = SpeechService()
        notificationResponseHandler = NotificationResponseHandler()

        Self.migrateLegacyDataIfNeeded(
            defaults: defaults,
            to: profiles.selectedProfileID
        )
        let prefix = ProfileManager.storagePrefix(
            for: profiles.selectedProfileID
        )
        let initialStore = VocabularyStore(
            defaults: defaults,
            storagePrefix: prefix
        )
        let initialSettings = AppSettings(
            defaults: defaults,
            storagePrefix: prefix
        )
        initialSettings.normalizeSelectedList(
            validListIDs: initialStore.validListIDs
        )
        if isUITesting {
            initialSettings.autoplayPronunciation = false
        }
        store = initialStore
        settings = initialSettings
        reminderStore = ReminderStore(
            profileID: profiles.selectedProfileID.uuidString,
            defaults: defaults
        )
        knownReminderStores[reminderStore.profileID] = reminderStore
        let deletedReminderProfileIDs = ReminderStore.deletedProfileIDs(
            defaults: defaults
        )
        if !deletedReminderProfileIDs.isEmpty {
            for deletedProfileID in deletedReminderProfileIDs {
                defaults.removeObject(
                    forKey: ReminderStore.storageKey(
                        for: deletedProfileID
                    )
                )
            }
            Task { @MainActor in
                let scheduler = NotificationScheduler()
                for deletedProfileID in deletedReminderProfileIDs {
                    await scheduler.removeAllRequests(
                        profileID: deletedProfileID
                    )
                }
            }
        }

        notificationResponseHandler.onResponse = { [weak self] payload in
            Task { @MainActor in
                _ = self?.handleNotificationPayload(payload)
            }
        }
        if installsNotificationDelegate {
            notificationResponseHandler.install()
        }
    }

    var activeProfile: UserProfile {
        profiles.selectedProfile
    }

    @discardableResult
    func selectProfile(id: UUID) -> Bool {
        guard profiles.select(id: id) else { return false }
        rebuildProfileState()
        return true
    }

    @discardableResult
    func createProfile(named name: String) -> UserProfile? {
        guard let profile = profiles.create(name: name) else { return nil }
        _ = profiles.select(id: profile.id)
        rebuildProfileState()
        return profile
    }

    @discardableResult
    func renameProfile(id: UUID, to name: String) -> Bool {
        profiles.rename(id: id, to: name)
    }

    @discardableResult
    func deleteProfile(id: UUID) -> Bool {
        store.save()
        let keys = profiles.profileDataKeys(for: id)
        guard profiles.delete(id: id) else { return false }
        let pendingNormalization = reminderNormalizationTask
        reminderNormalizationTask?.cancel()
        reminderNormalizationTask = nil
        let deletedProfileID = id.uuidString
        let deletedReminderStore = knownReminderStores.removeValue(
            forKey: deletedProfileID
        )
        if let deletedReminderStore {
            deletedReminderStore.invalidate()
        } else {
            ReminderStore.markProfileDeleted(
                profileID: deletedProfileID,
                defaults: defaults
            )
        }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        let reminderStorageKey = ReminderStore.storageKey(
            for: deletedProfileID
        )
        defaults.removeObject(forKey: reminderStorageKey)
        Task { @MainActor [weak self] in
            let scheduler = NotificationScheduler()
            await scheduler.removeAllRequests(
                profileID: deletedProfileID
            )
            await deletedReminderStore?.finishInvalidation()
            _ = await pendingNormalization?.value
            self?.defaults.removeObject(forKey: reminderStorageKey)
            await scheduler.removeAllRequests(
                profileID: deletedProfileID
            )
        }
        rebuildProfileState(savingCurrentStore: false)
        return true
    }

    @discardableResult
    func handleNotificationPayload(
        _ payload: StudyNotificationPayload
    ) -> Bool {
        guard profiles.profiles.contains(where: {
            $0.id == payload.profileID
        }) else {
            return false
        }

        if profiles.selectedProfileID != payload.profileID {
            guard selectProfile(id: payload.profileID) else {
                return false
            }
        }

        if
            let listID = payload.listID,
            store.validListIDs.contains(listID)
        {
            settings.selectedList = listID
        } else {
            settings.selectedList = 0
        }
        settings.onlyDifficult = payload.onlyDifficult
        pendingStudySessionRequest = StudySessionLaunchRequest(
            targetCount: payload.targetCount
        )
        selectedTab = .study
        return true
    }

    func takePendingStudySessionRequest() -> StudySessionLaunchRequest? {
        let request = pendingStudySessionRequest
        pendingStudySessionRequest = nil
        return request
    }

    func normalizeSelectedList() {
        let validListIDs = store.validListIDs
        let currentReminderStore = reminderStore
        settings.normalizeSelectedList(validListIDs: validListIDs)
        let previousTask = reminderNormalizationTask
        previousTask?.cancel()
        reminderNormalizationTask = Task { @MainActor in
            _ = await previousTask?.value
            guard !Task.isCancelled else { return }
            _ = await currentReminderStore.normalizeListReferences(
                validListIDs: validListIDs
            )
        }
    }

    private func rebuildProfileState(savingCurrentStore: Bool = true) {
        if savingCurrentStore {
            store.save()
        }
        let profileID = profiles.selectedProfileID
        let prefix = ProfileManager.storagePrefix(for: profileID)
        let newStore = VocabularyStore(
            defaults: defaults,
            storagePrefix: prefix
        )
        let newSettings = AppSettings(
            defaults: defaults,
            storagePrefix: prefix
        )
        newSettings.normalizeSelectedList(
            validListIDs: newStore.validListIDs
        )
        store = newStore
        settings = newSettings
        let reminderProfileID = profileID.uuidString
        let newReminderStore = knownReminderStores[reminderProfileID]
            ?? ReminderStore(
                profileID: reminderProfileID,
                defaults: defaults
            )
        reminderStore = newReminderStore
        knownReminderStores[reminderProfileID] = newReminderStore
        profileRevision += 1
    }

    private static func migrateLegacyDataIfNeeded(
        defaults: UserDefaults,
        to profileID: UUID
    ) {
        let markerKey = "wordflow.legacyMigration.v1"
        guard !defaults.bool(forKey: markerKey) else { return }

        let exactKeys = Set(ProfileManager.knownProfileRelativeKeys)
        let dynamicPrefixes = [
            "vocabulary.drawing.",
            "vocabulary.mistakes."
        ]
        let legacyKeys = defaults.dictionaryRepresentation().keys.filter {
            exactKeys.contains($0)
                || dynamicPrefixes.contains(where: $0.hasPrefix)
        }

        for legacyKey in legacyKeys {
            let destination = ProfileManager.storageKey(
                legacyKey,
                for: profileID
            )
            guard
                defaults.object(forKey: destination) == nil,
                let value = defaults.object(forKey: legacyKey)
            else {
                continue
            }
            defaults.set(value, forKey: destination)
        }
        defaults.set(true, forKey: markerKey)
    }
}

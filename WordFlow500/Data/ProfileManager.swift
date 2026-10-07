import Foundation
import Observation

enum ProfileDataNamespace {
    static let rootPrefix = "wordflow.profile."

    static func prefix(for profileID: UUID) -> String {
        "\(rootPrefix)\(profileID.uuidString.lowercased())."
    }

    static func key(_ relativeKey: String, for profileID: UUID) -> String {
        "\(prefix(for: profileID))\(relativeKey)"
    }

    static func contains(_ key: String, for profileID: UUID) -> Bool {
        key.hasPrefix(prefix(for: profileID))
    }
}

@MainActor
@Observable
final class ProfileManager {
    private enum Storage {
        static let profilesKey = "wordflow.profiles.v1"
        static let selectedProfileIDKey = "wordflow.profiles.selectedID.v1"
    }

    static let primaryProfileName = "Основной"

    /// Existing application keys that can be migrated into a profile namespace.
    /// Per-word drawing and mistake keys are dynamic and should be discovered by
    /// their legacy prefixes when migration is implemented.
    static let knownProfileRelativeKeys = [
        "vocabulary.words.v1",
        "vocabulary.lists.v1",
        "vocabulary.nextListID.v1",
        "vocabulary.words.recoveryBackup.v1",
        "vocabulary.translationSeedVersion",
        "settings.studyMode",
        "settings.showsDrawingCanvas",
        "settings.automaticallyShowsAnswer",
        "settings.onlyDifficult",
        "settings.autoplayPronunciation",
        "settings.isDarkMode",
        "settings.selectedList"
    ]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()

    private(set) var profiles: [UserProfile]
    private(set) var selectedProfileID: UUID

    var selectedProfile: UserProfile {
        profiles.first { $0.id == selectedProfileID } ?? profiles[0]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let decoder = JSONDecoder()
        let loadedProfiles = defaults.data(forKey: Storage.profilesKey)
            .flatMap { try? decoder.decode([UserProfile].self, from: $0) }
            .map(Self.repairedProfiles(_:))
            ?? []

        if loadedProfiles.isEmpty {
            let primaryProfile = UserProfile(name: Self.primaryProfileName)
            profiles = [primaryProfile]
            selectedProfileID = primaryProfile.id
        } else {
            profiles = loadedProfiles
            let persistedSelection = defaults
                .string(forKey: Storage.selectedProfileIDKey)
                .flatMap(UUID.init(uuidString:))
            selectedProfileID = persistedSelection.flatMap { candidate in
                loadedProfiles.contains { $0.id == candidate } ? candidate : nil
            } ?? loadedProfiles[0].id
        }

        persist()
    }

    @discardableResult
    func create(name: String) -> UserProfile? {
        guard
            let normalizedName = Self.normalizedName(name),
            isNameAvailable(normalizedName)
        else {
            return nil
        }

        let profile = UserProfile(name: normalizedName)
        profiles.append(profile)
        persist()
        return profile
    }

    @discardableResult
    func rename(id: UUID, to name: String) -> Bool {
        guard
            let index = profiles.firstIndex(where: { $0.id == id }),
            let normalizedName = Self.normalizedName(name),
            isNameAvailable(normalizedName, excluding: id)
        else {
            return false
        }

        profiles[index].name = normalizedName
        persist()
        return true
    }

    @discardableResult
    func select(id: UUID) -> Bool {
        guard profiles.contains(where: { $0.id == id }) else {
            return false
        }
        guard selectedProfileID != id else {
            return true
        }

        selectedProfileID = id
        persist()
        return true
    }

    /// Removes only the profile record. Namespaced learning data is deliberately
    /// left untouched so a caller can decide when to perform a recoverable cleanup.
    @discardableResult
    func delete(id: UUID) -> Bool {
        guard
            profiles.count > 1,
            let removedIndex = profiles.firstIndex(where: { $0.id == id })
        else {
            return false
        }

        profiles.remove(at: removedIndex)
        if selectedProfileID == id {
            let replacementIndex = min(removedIndex, profiles.count - 1)
            selectedProfileID = profiles[replacementIndex].id
        }
        persist()
        return true
    }

    static func storagePrefix(for profileID: UUID) -> String {
        ProfileDataNamespace.prefix(for: profileID)
    }

    static func storageKey(_ relativeKey: String, for profileID: UUID) -> String {
        ProfileDataNamespace.key(relativeKey, for: profileID)
    }

    static func knownProfileKeys(for profileID: UUID) -> [String] {
        knownProfileRelativeKeys.map { storageKey($0, for: profileID) }
    }

    /// Returns only keys already stored inside this profile's namespace. The
    /// returned list is safe to offer to an explicit cleanup operation.
    func profileDataKeys(for profileID: UUID) -> [String] {
        defaults.dictionaryRepresentation().keys
            .filter { ProfileDataNamespace.contains($0, for: profileID) }
            .sorted()
    }

    private func isNameAvailable(
        _ proposedName: String,
        excluding excludedID: UUID? = nil
    ) -> Bool {
        let proposedKey = Self.uniquenessKey(for: proposedName)
        return profiles.allSatisfy { profile in
            profile.id == excludedID
                || Self.uniquenessKey(for: profile.name) != proposedKey
        }
    }

    private func persist() {
        guard let encodedProfiles = try? encoder.encode(profiles) else {
            return
        }
        defaults.set(encodedProfiles, forKey: Storage.profilesKey)
        defaults.set(
            selectedProfileID.uuidString.lowercased(),
            forKey: Storage.selectedProfileIDKey
        )
    }

    private static func normalizedName(_ name: String) -> String? {
        let normalized = name
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func uniquenessKey(for name: String) -> String {
        name
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ru_RU")
            )
            .lowercased(with: Locale(identifier: "ru_RU"))
    }

    private static func repairedProfiles(
        _ persistedProfiles: [UserProfile]
    ) -> [UserProfile] {
        var repaired: [UserProfile] = []
        var seenIDs = Set<UUID>()
        var seenNames = Set<String>()

        for persistedProfile in persistedProfiles {
            guard
                seenIDs.insert(persistedProfile.id).inserted,
                let normalizedName = normalizedName(persistedProfile.name)
            else {
                continue
            }

            let nameKey = uniquenessKey(for: normalizedName)
            guard seenNames.insert(nameKey).inserted else {
                continue
            }

            repaired.append(
                UserProfile(id: persistedProfile.id, name: normalizedName)
            )
        }

        return repaired
    }
}

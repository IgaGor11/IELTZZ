import Foundation

@MainActor
enum PreviewFixtures {
    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "WordFlow500.Previews")!
        defaults.removePersistentDomain(forName: "WordFlow500.Previews")
        return defaults
    }()

    static let store = VocabularyStore(defaults: defaults)

    static let settings: AppSettings = {
        let settings = AppSettings(defaults: defaults)
        settings.autoplayPronunciation = false
        return settings
    }()

    static let speech = SpeechService()
}


import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let studyMode = "settings.studyMode"
        static let showsDrawingCanvas = "settings.showsDrawingCanvas"
        static let automaticallyShowsAnswer = "settings.automaticallyShowsAnswer"
        static let onlyDifficult = "settings.onlyDifficult"
        static let autoplayPronunciation = "settings.autoplayPronunciation"
        static let isDarkMode = "settings.isDarkMode"
        static let selectedList = "settings.selectedList"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storagePrefix: String

    var studyMode: StudyMode {
        didSet { defaults.set(studyMode.rawValue, forKey: key(Key.studyMode)) }
    }

    var showsDrawingCanvas: Bool {
        didSet { defaults.set(showsDrawingCanvas, forKey: key(Key.showsDrawingCanvas)) }
    }

    var automaticallyShowsAnswer: Bool {
        didSet {
            defaults.set(
                automaticallyShowsAnswer,
                forKey: key(Key.automaticallyShowsAnswer)
            )
        }
    }

    var onlyDifficult: Bool {
        didSet { defaults.set(onlyDifficult, forKey: key(Key.onlyDifficult)) }
    }

    var autoplayPronunciation: Bool {
        didSet {
            defaults.set(
                autoplayPronunciation,
                forKey: key(Key.autoplayPronunciation)
            )
        }
    }

    var isDarkMode: Bool {
        didSet { defaults.set(isDarkMode, forKey: key(Key.isDarkMode)) }
    }

    var selectedList: Int {
        didSet { defaults.set(selectedList, forKey: key(Key.selectedList)) }
    }

    init(
        defaults: UserDefaults = .standard,
        storagePrefix: String = ""
    ) {
        self.defaults = defaults
        self.storagePrefix = storagePrefix

        func storedKey(_ base: String) -> String {
            storagePrefix + base
        }

        studyMode = defaults.string(forKey: storedKey(Key.studyMode))
            .flatMap(StudyMode.init(rawValue:)) ?? .wordToTranslation
        showsDrawingCanvas =
            defaults.object(forKey: storedKey(Key.showsDrawingCanvas)) as? Bool
                ?? true
        automaticallyShowsAnswer = defaults.bool(
            forKey: storedKey(Key.automaticallyShowsAnswer)
        )
        onlyDifficult = defaults.bool(forKey: storedKey(Key.onlyDifficult))
        autoplayPronunciation =
            defaults.object(forKey: storedKey(Key.autoplayPronunciation)) as? Bool
                ?? true
        isDarkMode = defaults.bool(forKey: storedKey(Key.isDarkMode))
        selectedList = max(defaults.integer(forKey: storedKey(Key.selectedList)), 0)
    }

    var sessionSignature: String {
        "\(studyMode.rawValue)|\(onlyDifficult)|\(selectedList)"
    }

    func normalizeSelectedList(validListIDs: Set<Int>) {
        guard selectedList != 0, !validListIDs.contains(selectedList) else {
            return
        }
        selectedList = 0
    }

    private func key(_ base: String) -> String {
        storagePrefix + base
    }
}

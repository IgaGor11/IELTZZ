import Foundation
import Observation

@MainActor
@Observable
final class VocabularyStore {
    private enum Storage {
        static let wordsKey = "vocabulary.words.v1"
        static let listsKey = "vocabulary.lists.v1"
        static let nextListIDKey = "vocabulary.nextListID.v1"
        static let recoveryBackupKey = "vocabulary.words.recoveryBackup.v1"
        static let translationSeedVersionKey = "vocabulary.translationSeedVersion"
        static let currentTranslationSeedVersion = 1

        static func drawingKey(for id: Int) -> String {
            "vocabulary.drawing.\(id)"
        }

        static func mistakesKey(for id: Int) -> String {
            "vocabulary.mistakes.\(id)"
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storagePrefix: String
    @ObservationIgnored private let encoder: JSONEncoder
    @ObservationIgnored private let decoder: JSONDecoder
    @ObservationIgnored private var nextListID = 6

    private(set) var words: [VocabularyWord]
    private(set) var lists: [VocabularyList]
    private(set) var resetRevision = 0
    private(set) var contentRevision = 0

    init(
        defaults: UserDefaults = .standard,
        storagePrefix: String = ""
    ) {
        self.defaults = defaults
        self.storagePrefix = storagePrefix
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let listsKey = storagePrefix + Storage.listsKey
        if
            let data = defaults.data(forKey: listsKey),
            let storedLists = try? decoder.decode([VocabularyList].self, from: data)
        {
            lists = Self.mergingLists(storedLists)
        } else {
            lists = VocabularyList.builtIn
        }
        let wordsKey = storagePrefix + Storage.wordsKey
        if let data = defaults.data(forKey: wordsKey) {
            if let storedWords = try? decoder.decode([VocabularyWord].self, from: data) {
                let shouldSeedMissingTranslations =
                    defaults.integer(
                        forKey: storagePrefix + Storage.translationSeedVersionKey
                    ) < Storage.currentTranslationSeedVersion
                words = Self.merging(
                    storedWords: storedWords,
                    seedMissingTranslations: shouldSeedMissingTranslations
                )
            } else {
                defaults.set(
                    data,
                    forKey: storagePrefix + Storage.recoveryBackupKey
                )
                words = Self.freshWords()
            }
        } else {
            words = Self.freshWords()
        }

        Self.ensureListsCoverAllWords(lists: &lists, words: words)
        nextListID = max(
            6,
            defaults.integer(
                forKey: storagePrefix + Storage.nextListIDKey
            ),
            (lists.map(\.id).max() ?? 5) + 1
        )
        hydrateDrawings()
        hydrateMistakes()
        defaults.set(
            Storage.currentTranslationSeedVersion,
            forKey: storagePrefix + Storage.translationSeedVersionKey
        )
        save()
    }

    var validListIDs: Set<Int> {
        Set(lists.map(\.id))
    }

    func word(id: Int) -> VocabularyWord? {
        words.first { $0.id == id }
    }

    func list(id: Int) -> VocabularyList? {
        lists.first { $0.id == id }
    }

    func listName(for id: Int) -> String {
        list(id: id)?.name ?? "Список \(id)"
    }

    @discardableResult
    func addList(named rawName: String) throws -> VocabularyList {
        let name = rawName.normalizedWhitespace
        guard !name.isEmpty else {
            throw VocabularyStoreError.emptyListName
        }
        guard !lists.contains(where: {
            $0.name.compare(
                name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }) else {
            throw VocabularyStoreError.duplicateListName
        }

        let newList = VocabularyList(
            id: nextListID,
            name: name
        )
        nextListID += 1
        lists.append(newList)
        contentRevision += 1
        save()
        return newList
    }

    func renameList(id: Int, to rawName: String) throws {
        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw VocabularyStoreError.missingList
        }
        let name = rawName.normalizedWhitespace
        guard !name.isEmpty else {
            throw VocabularyStoreError.emptyListName
        }
        guard !lists.contains(where: {
            $0.id != id
                && $0.name.compare(
                    name,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
        }) else {
            throw VocabularyStoreError.duplicateListName
        }
        lists[index].name = name
        contentRevision += 1
        save()
    }

    /// Custom lists are removed without losing vocabulary: their words move to
    /// the first remaining list.
    @discardableResult
    func deleteList(id: Int) throws -> Int {
        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw VocabularyStoreError.missingList
        }
        guard !lists[index].isBuiltIn else {
            throw VocabularyStoreError.builtInListDeletion
        }
        guard let fallbackID = lists.first(where: { $0.id != id })?.id else {
            throw VocabularyStoreError.missingList
        }

        let movedCount = words.count { $0.listNumber == id }
        for wordIndex in words.indices where words[wordIndex].listNumber == id {
            words[wordIndex].listNumber = fallbackID
        }
        lists.remove(at: index)
        contentRevision += 1
        save()
        return movedCount
    }

    @discardableResult
    func addWord(
        _ rawWord: String,
        translation rawTranslation: String = "",
        example rawExample: String = "",
        toList listID: Int
    ) throws -> VocabularyWord {
        guard lists.contains(where: { $0.id == listID }) else {
            throw VocabularyStoreError.missingList
        }
        let english = rawWord.normalizedWhitespace
        guard !english.isEmpty else {
            throw VocabularyStoreError.emptyWord
        }
        guard !containsWord(named: english) else {
            throw VocabularyStoreError.duplicateWord(english)
        }

        let newWord = VocabularyWord(
            id: max((words.map(\.id).max() ?? 0) + 1, 501),
            word: english,
            listNumber: listID,
            translation: rawTranslation.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            example: rawExample.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
        words.append(newWord)
        contentRevision += 1
        save()
        return newWord
    }

    func importWords(_ text: String, toList listID: Int) throws -> BatchImportResult {
        guard lists.contains(where: { $0.id == listID }) else {
            throw VocabularyStoreError.missingList
        }

        let drafts = Self.batchDrafts(from: text)
        var existing = Set(words.map { AnswerMatcher.normalized($0.word) })
        var skipped: [String] = []
        var addedCount = 0
        var nextID = max((words.map(\.id).max() ?? 0) + 1, 501)

        for draft in drafts {
            let english = draft.word.normalizedWhitespace
            let normalized = AnswerMatcher.normalized(english)
            guard !normalized.isEmpty else { continue }
            guard existing.insert(normalized).inserted else {
                skipped.append("\(english) — уже существует")
                continue
            }

            words.append(
                VocabularyWord(
                    id: nextID,
                    word: english,
                    listNumber: listID,
                    translation: draft.translation.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    example: draft.example.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
            )
            nextID += 1
            addedCount += 1
        }

        if addedCount > 0 {
            contentRevision += 1
            save()
        }
        return BatchImportResult(
            addedCount: addedCount,
            skippedEntries: skipped
        )
    }

    func updateWord(
        id: Int,
        english rawEnglish: String,
        translation: String,
        example: String,
        listID: Int
    ) throws {
        guard lists.contains(where: { $0.id == listID }) else {
            throw VocabularyStoreError.missingList
        }
        let english = rawEnglish.normalizedWhitespace
        guard !english.isEmpty else {
            throw VocabularyStoreError.emptyWord
        }
        guard !words.contains(where: {
            $0.id != id
                && AnswerMatcher.normalized($0.word)
                    == AnswerMatcher.normalized(english)
        }) else {
            throw VocabularyStoreError.duplicateWord(english)
        }

        mutateWord(id: id) { word in
            word.word = english
            word.translation = translation.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            word.example = example.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            word.listNumber = listID
        }
        contentRevision += 1
    }

    func deleteWord(id: Int) throws {
        guard id > SeedWords.all.count else {
            throw VocabularyStoreError.builtInWordDeletion
        }
        guard let index = words.firstIndex(where: { $0.id == id }) else {
            return
        }
        words.remove(at: index)
        defaults.removeObject(forKey: key(Storage.drawingKey(for: id)))
        defaults.removeObject(forKey: key(Storage.mistakesKey(for: id)))
        contentRevision += 1
        save()
    }

    func updateTranslation(_ translation: String, example: String, for id: Int) {
        mutateWord(id: id) { word in
            word.translation = translation
            word.example = example
        }
    }

    func updateExample(_ example: String, for id: Int) {
        mutateWord(id: id) { $0.example = example }
    }

    func updateDrawing(_ drawing: Data?, for id: Int) {
        if let drawing {
            defaults.set(drawing, forKey: key(Storage.drawingKey(for: id)))
        } else {
            defaults.removeObject(forKey: key(Storage.drawingKey(for: id)))
        }
        mutateWord(id: id) { $0.associationDrawing = drawing }
    }

    func toggleDifficult(id: Int) {
        mutateWord(id: id) { $0.isDifficult.toggle() }
    }

    func setDifficult(_ isDifficult: Bool, for id: Int) {
        mutateWord(id: id) { $0.isDifficult = isDifficult }
    }

    func grade(
        id: Int,
        isCorrect: Bool,
        submittedAnswer: String? = nil,
        mode: StudyMode = .wordToTranslation,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        mutateWord(id: id) { word in
            let outcome = SpacedRepetition.outcome(
                currentLevel: word.level,
                isCorrect: isCorrect,
                practicedAt: date,
                calendar: calendar
            )
            word.level = outcome.level
            word.nextReviewDate = outcome.nextReviewDate
            word.lastPracticeDate = date
            if isCorrect {
                word.correctCount += 1
                if var history = word.mistakeHistory {
                    for index in history.indices where
                        history[index].correctedAt == nil
                            && history[index].mode == mode
                    {
                        history[index].correctedAt = date
                    }
                    word.mistakeHistory = history
                }
            } else {
                word.incorrectCount += 1
                let expectedAnswer = Self.expectedAnswer(for: word, mode: mode)
                var history = word.mistakeHistory ?? []
                history.append(
                    MistakeRecord(
                        submittedAnswer: submittedAnswer?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .nilIfEmpty,
                        expectedAnswer: expectedAnswer,
                        mode: mode,
                        practicedAt: date,
                        analysis: MistakeAnalyzer.message(
                            submittedAnswer: submittedAnswer,
                            expectedAnswer: expectedAnswer,
                            mode: mode
                        )
                    )
                )
                word.mistakeHistory = Array(history.suffix(20))
            }
        }
        persistMistakes(for: id)
    }

    func resetProgress() {
        for index in words.indices {
            words[index].level = 0
            words[index].nextReviewDate = nil
            words[index].correctCount = 0
            words[index].incorrectCount = 0
            words[index].isDifficult = false
            words[index].lastPracticeDate = nil
            words[index].mistakeHistory = nil
            defaults.removeObject(
                forKey: key(Storage.mistakesKey(for: words[index].id))
            )
        }
        resetRevision += 1
        save()
    }

    func save() {
        let lightweightWords = words.map { word in
            var copy = word
            copy.associationDrawing = nil
            copy.mistakeHistory = nil
            return copy
        }
        if let data = try? encoder.encode(lightweightWords) {
            defaults.set(data, forKey: key(Storage.wordsKey))
        }
        if let data = try? encoder.encode(lists) {
            defaults.set(data, forKey: key(Storage.listsKey))
        }
        defaults.set(nextListID, forKey: key(Storage.nextListIDKey))
    }

    func statistics(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> LearningStatistics {
        let today = calendar.startOfDay(for: date)
        return LearningStatistics(
            totalWords: words.count,
            learnedWords: words.count { $0.level >= 3 },
            translatedWords: words.count(where: \.hasTranslation),
            difficultWords: words.count(where: \.isDifficult),
            correctAnswers: words.reduce(0) { $0 + $1.correctCount },
            incorrectAnswers: words.reduce(0) { $0 + $1.incorrectCount },
            practicedToday: words.count { word in
                guard let lastPracticeDate = word.lastPracticeDate else {
                    return false
                }
                return calendar.startOfDay(for: lastPracticeDate) == today
            }
        )
    }

    private func containsWord(named english: String) -> Bool {
        let normalized = AnswerMatcher.normalized(english)
        return words.contains {
            AnswerMatcher.normalized($0.word) == normalized
        }
    }

    private func mutateWord(
        id: Int,
        mutation: (inout VocabularyWord) -> Void
    ) {
        guard let index = words.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutation(&words[index])
        save()
    }

    private func key(_ base: String) -> String {
        storagePrefix + base
    }

    private static func freshWords() -> [VocabularyWord] {
        SeedWords.all.map { seed in
            VocabularyWord(
                id: seed.id,
                word: seed.word,
                listNumber: seed.listNumber,
                translation: SeedWords.translation(for: seed.id)
            )
        }
    }

    private static func merging(
        storedWords: [VocabularyWord],
        seedMissingTranslations: Bool
    ) -> [VocabularyWord] {
        let storedByID = storedWords.reduce(into: [Int: VocabularyWord]()) {
            $0[$1.id] = $1
        }
        let seedIDs = Set(SeedWords.all.map(\.id))
        var merged = SeedWords.all.map { seed in
            guard var stored = storedByID[seed.id] else {
                return VocabularyWord(
                    id: seed.id,
                    word: seed.word,
                    listNumber: seed.listNumber,
                    translation: SeedWords.translation(for: seed.id)
                )
            }
            if seedMissingTranslations, !stored.hasTranslation {
                stored.translation = SeedWords.translation(for: seed.id)
            }
            return stored
        }
        merged.append(
            contentsOf: storedWords
                .filter { !seedIDs.contains($0.id) }
                .sorted { $0.id < $1.id }
        )
        return merged
    }

    private static func mergingLists(
        _ storedLists: [VocabularyList]
    ) -> [VocabularyList] {
        let storedByID = storedLists.reduce(into: [Int: VocabularyList]()) {
            $0[$1.id] = $1
        }
        var merged = VocabularyList.builtIn.map { builtIn in
            guard let stored = storedByID[builtIn.id] else {
                return builtIn
            }
            return VocabularyList(
                id: builtIn.id,
                name: stored.name.normalizedWhitespace.nilIfEmpty
                    ?? builtIn.name,
                isBuiltIn: true,
                createdAt: stored.createdAt
            )
        }
        merged.append(
            contentsOf: storedLists
                .filter { $0.id > 5 }
                .map {
                    VocabularyList(
                        id: $0.id,
                        name: $0.name.normalizedWhitespace.nilIfEmpty
                            ?? "Список \($0.id)",
                        isBuiltIn: false,
                        createdAt: $0.createdAt
                    )
                }
                .sorted { $0.createdAt < $1.createdAt }
        )
        return merged
    }

    private static func ensureListsCoverAllWords(
        lists: inout [VocabularyList],
        words: [VocabularyWord]
    ) {
        let existingIDs = Set(lists.map(\.id))
        let missingIDs = Set(words.map(\.listNumber))
            .subtracting(existingIDs)
            .sorted()
        lists.append(
            contentsOf: missingIDs.map {
                VocabularyList(id: $0, name: "Список \($0)")
            }
        )
    }

    private func hydrateDrawings() {
        for index in words.indices {
            let drawingKey = key(Storage.drawingKey(for: words[index].id))
            if let separateDrawing = defaults.data(forKey: drawingKey) {
                words[index].associationDrawing = separateDrawing
            } else if let legacyDrawing = words[index].associationDrawing {
                defaults.set(legacyDrawing, forKey: drawingKey)
            }
        }
    }

    private func hydrateMistakes() {
        for index in words.indices {
            let mistakesKey = key(Storage.mistakesKey(for: words[index].id))
            if
                let data = defaults.data(forKey: mistakesKey),
                let history = try? decoder.decode([MistakeRecord].self, from: data)
            {
                words[index].mistakeHistory = history
            } else if
                let legacyHistory = words[index].mistakeHistory,
                let data = try? encoder.encode(legacyHistory)
            {
                defaults.set(data, forKey: mistakesKey)
            }
        }
    }

    private func persistMistakes(for id: Int) {
        guard let word = word(id: id) else { return }
        let mistakesKey = key(Storage.mistakesKey(for: id))
        guard !word.recentMistakes.isEmpty else {
            defaults.removeObject(forKey: mistakesKey)
            return
        }
        guard let data = try? encoder.encode(word.recentMistakes) else {
            return
        }
        defaults.set(data, forKey: mistakesKey)
    }

    private static func expectedAnswer(
        for word: VocabularyWord,
        mode: StudyMode
    ) -> String {
        switch mode {
        case .wordToTranslation, .multipleChoice:
            word.trimmedTranslation
        case .translationToWord, .spelling:
            word.word
        }
    }

    private struct BatchDraft {
        let word: String
        let translation: String
        let example: String
    }

    private static func batchDrafts(from rawText: String) -> [BatchDraft] {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let hasStructuredDelimiter = text.contains("|")
            || text.contains("\t")
            || text.contains(";")

        if lines.count == 1, !hasStructuredDelimiter, text.contains(",") {
            return text.split(separator: ",").map {
                BatchDraft(
                    word: String($0),
                    translation: "",
                    example: ""
                )
            }
        }

        return lines.compactMap { line in
            let delimiter: Character? = if line.contains("\t") {
                "\t"
            } else if line.contains("|") {
                "|"
            } else if line.contains(";") {
                ";"
            } else {
                nil
            }

            guard let delimiter else {
                return BatchDraft(word: line, translation: "", example: "")
            }
            let parts = line.split(
                separator: delimiter,
                maxSplits: 2,
                omittingEmptySubsequences: false
            )
            return BatchDraft(
                word: parts.indices.contains(0) ? String(parts[0]) : "",
                translation: parts.indices.contains(1) ? String(parts[1]) : "",
                example: parts.indices.contains(2) ? String(parts[2]) : ""
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var normalizedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

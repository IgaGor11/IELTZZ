import XCTest
@testable import WordFlow500

@MainActor
final class VocabularyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WordFlow500Tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshStoreSeedsExactlyOnceAndPersistsEdits() {
        let firstStore = VocabularyStore(defaults: defaults)
        XCTAssertEqual(firstStore.words.count, 500)
        XCTAssertEqual(firstStore.statistics().translatedWords, 500)
        XCTAssertEqual(firstStore.word(id: 500)?.translation, "посредством чего")
        firstStore.updateTranslation("достигать", example: "Achieve a goal.", for: 1)

        let secondStore = VocabularyStore(defaults: defaults)
        XCTAssertEqual(secondStore.words.count, 500)
        XCTAssertEqual(secondStore.word(id: 1)?.translation, "достигать")
        XCTAssertEqual(secondStore.word(id: 1)?.example, "Achieve a goal.")
    }

    func testResetPreservesUserContentAndDrawing() {
        let store = VocabularyStore(defaults: defaults)
        let drawing = Data([1, 2, 3])
        store.updateTranslation("достигать", example: "Example", for: 1)
        store.updateDrawing(drawing, for: 1)
        store.setDifficult(true, for: 1)
        store.grade(id: 1, isCorrect: true)

        store.resetProgress()

        let word = store.word(id: 1)
        XCTAssertEqual(word?.translation, "достигать")
        XCTAssertEqual(word?.example, "Example")
        XCTAssertEqual(word?.associationDrawing, drawing)
        XCTAssertEqual(word?.level, 0)
        XCTAssertNil(word?.nextReviewDate)
        XCTAssertNil(word?.lastPracticeDate)
        XCTAssertEqual(word?.correctCount, 0)
        XCTAssertEqual(word?.incorrectCount, 0)
        XCTAssertEqual(word?.isDifficult, false)
        XCTAssertEqual(store.resetRevision, 1)

        let reopenedStore = VocabularyStore(defaults: defaults)
        XCTAssertEqual(reopenedStore.word(id: 1)?.associationDrawing, drawing)
    }

    func testLegacyEmptyTranslationsAreSeededOnceWithoutOverwritingUserEdits() throws {
        var legacyWords = SeedWords.all.map {
            VocabularyWord(id: $0.id, word: $0.word, listNumber: $0.listNumber)
        }
        legacyWords[0].translation = "мой перевод"
        defaults.set(
            try JSONEncoder().encode(legacyWords),
            forKey: "vocabulary.words.v1"
        )

        let migratedStore = VocabularyStore(defaults: defaults)
        XCTAssertEqual(migratedStore.word(id: 1)?.translation, "мой перевод")
        XCTAssertEqual(migratedStore.word(id: 2)?.translation, "управление")

        migratedStore.updateTranslation("", example: "", for: 2)
        let reopenedStore = VocabularyStore(defaults: defaults)
        XCTAssertEqual(reopenedStore.word(id: 2)?.translation, "")
    }

    func testCorruptedPayloadIsBackedUpBeforeFreshSeedIsSaved() {
        let corruptedData = Data("not-json".utf8)
        defaults.set(corruptedData, forKey: "vocabulary.words.v1")

        let store = VocabularyStore(defaults: defaults)

        XCTAssertEqual(store.words.count, 500)
        XCTAssertEqual(
            defaults.data(forKey: "vocabulary.words.recoveryBackup.v1"),
            corruptedData
        )
        XCTAssertNotEqual(defaults.data(forKey: "vocabulary.words.v1"), corruptedData)
    }

    func testMistakeHistoryPersistsAndResetClearsIt() {
        let store = VocabularyStore(defaults: defaults)
        store.grade(
            id: 1,
            isCorrect: false,
            submittedAnswer: "достовать",
            mode: .wordToTranslation
        )

        let reopenedStore = VocabularyStore(defaults: defaults)
        let mistake = reopenedStore.word(id: 1)?.recentMistakes.last
        XCTAssertEqual(mistake?.submittedAnswer, "достовать")
        XCTAssertEqual(mistake?.expectedAnswer, "достигать")
        XCTAssertEqual(mistake?.mode, .wordToTranslation)
        XCTAssertNil(mistake?.correctedAt)

        reopenedStore.grade(
            id: 1,
            isCorrect: false,
            submittedAnswer: "достегать",
            mode: .wordToTranslation
        )
        reopenedStore.grade(id: 1, isCorrect: true)
        XCTAssertTrue(
            reopenedStore.word(id: 1)?.recentMistakes
                .allSatisfy { $0.correctedAt != nil } == true
        )
        reopenedStore.resetProgress()
        XCTAssertTrue(reopenedStore.word(id: 1)?.recentMistakes.isEmpty == true)
    }

    func testStatisticsAreAccurateAndCountUniqueWordsToday() {
        let store = VocabularyStore(defaults: defaults)
        store.grade(id: 1, isCorrect: true)
        store.grade(id: 1, isCorrect: true)
        store.grade(id: 2, isCorrect: false)
        store.updateTranslation("перевод", example: "", for: 1)
        store.setDifficult(true, for: 2)

        let statistics = store.statistics()
        XCTAssertEqual(statistics.totalWords, 500)
        XCTAssertEqual(statistics.translatedWords, 500)
        XCTAssertEqual(statistics.difficultWords, 1)
        XCTAssertEqual(statistics.correctAnswers, 2)
        XCTAssertEqual(statistics.incorrectAnswers, 1)
        XCTAssertEqual(statistics.practicedToday, 2)
        XCTAssertEqual(statistics.accuracy, 200.0 / 3.0, accuracy: 0.001)
    }

    func testCustomListsWordsAndBatchImportPersist() throws {
        let store = VocabularyStore(defaults: defaults)
        let customList = try store.addList(named: "Работа")
        let customWord = try store.addWord(
            "deadline",
            translation: "крайний срок",
            example: "We met the deadline.",
            toList: customList.id
        )
        let result = try store.importWords(
            """
            briefing | инструктаж | We have a morning briefing.
            stakeholder\tзаинтересованная сторона\tAsk every stakeholder.
            deadline | повтор
            """,
            toList: customList.id
        )

        XCTAssertEqual(result.addedCount, 2)
        XCTAssertEqual(result.skippedEntries.count, 1)
        XCTAssertEqual(store.words.count, 503)

        let reopened = VocabularyStore(defaults: defaults)
        XCTAssertEqual(reopened.list(id: customList.id)?.name, "Работа")
        XCTAssertEqual(reopened.word(id: customWord.id)?.word, "deadline")
        XCTAssertTrue(
            reopened.words.contains {
                $0.word == "briefing"
                    && $0.translation == "инструктаж"
                    && $0.listNumber == customList.id
            }
        )
    }

    func testRenamingAndDeletingCustomListMovesWordsWithoutDataLoss() throws {
        let store = VocabularyStore(defaults: defaults)
        let list = try store.addList(named: "Временный")
        let word = try store.addWord(
            "roadmap",
            translation: "план",
            toList: list.id
        )

        try store.renameList(id: list.id, to: "Проекты")
        XCTAssertEqual(store.list(id: list.id)?.name, "Проекты")

        let movedCount = try store.deleteList(id: list.id)
        XCTAssertEqual(movedCount, 1)
        XCTAssertNil(store.list(id: list.id))
        XCTAssertNotEqual(store.word(id: word.id)?.listNumber, list.id)
        XCTAssertEqual(store.word(id: word.id)?.translation, "план")
    }

    func testDeletedListIdentifierIsNeverReused() throws {
        let store = VocabularyStore(defaults: defaults)
        let deletedList = try store.addList(named: "Будет удалён")

        try store.deleteList(id: deletedList.id)
        let replacement = try store.addList(named: "Новый список")

        XCTAssertNotEqual(replacement.id, deletedList.id)
        XCTAssertGreaterThan(replacement.id, deletedList.id)

        let reopened = VocabularyStore(defaults: defaults)
        let another = try reopened.addList(named: "Ещё один список")
        XCTAssertGreaterThan(another.id, replacement.id)
    }

    func testProfileStoragePrefixesAreIsolated() {
        let first = VocabularyStore(
            defaults: defaults,
            storagePrefix: "profile.first."
        )
        first.grade(id: 1, isCorrect: true)
        first.updateTranslation("первый", example: "", for: 1)

        let second = VocabularyStore(
            defaults: defaults,
            storagePrefix: "profile.second."
        )

        XCTAssertEqual(first.word(id: 1)?.level, 1)
        XCTAssertEqual(second.word(id: 1)?.level, 0)
        XCTAssertEqual(second.word(id: 1)?.translation, "достигать")
    }
}

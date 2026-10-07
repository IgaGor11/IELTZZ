import XCTest
@testable import WordFlow500

@MainActor
final class StudySessionTests: XCTestCase {
    func testDefaultEnglishToRussianSessionKeepsBuiltInAnswerHidden() {
        let suiteName = "StudySessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let session = StudySession()

        session.start(store: store, settings: settings)

        XCTAssertEqual(settings.studyMode, .wordToTranslation)
        XCTAssertFalse(settings.automaticallyShowsAnswer)
        XCTAssertFalse(session.isAnswerRevealed)
        XCTAssertNotNil(session.currentWordID)
    }

    func testIncorrectAnswerIsSavedAndQueuedForRetry() {
        let suiteName = "StudySessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let session = StudySession()
        session.start(store: store, settings: settings)
        let initialCount = session.totalCount
        let currentID = try! XCTUnwrap(session.currentWordID)
        let currentWord = try! XCTUnwrap(store.word(id: currentID))

        session.typedAnswer = "неверный ответ"
        session.checkTypedAnswer(
            for: currentWord,
            mode: settings.studyMode,
            store: store,
            settings: settings
        )

        XCTAssertEqual(session.totalCount, initialCount + 1)
        XCTAssertEqual(session.mistakesThisSession, 1)
        XCTAssertEqual(
            store.word(id: currentID)?.recentMistakes.last?.submittedAnswer,
            "неверный ответ"
        )
        session.cancelPendingTransition()
    }

    func testRetriesAreLimitedToTwoPerWordInOneSession() {
        let suiteName = "StudySessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let session = StudySession()
        session.start(store: store, settings: settings)
        let originalCount = session.totalCount
        let repeatedWordID = try! XCTUnwrap(session.currentWordID)

        answerCurrent(
            correctly: false,
            session: session,
            store: store,
            settings: settings
        )
        moveAcrossThreeCards(session: session, store: store, settings: settings)
        XCTAssertEqual(session.currentWordID, repeatedWordID)

        answerCurrent(
            correctly: false,
            session: session,
            store: store,
            settings: settings
        )
        moveAcrossThreeCards(session: session, store: store, settings: settings)
        XCTAssertEqual(session.currentWordID, repeatedWordID)

        answerCurrent(
            correctly: false,
            session: session,
            store: store,
            settings: settings
        )

        XCTAssertEqual(session.totalCount, originalCount + 2)
        XCTAssertEqual(session.mistakesThisSession, 3)
        XCTAssertEqual(
            store.word(id: repeatedWordID)?.recentMistakes.count,
            3
        )
    }

    func testMultipleChoiceWaitsForExplicitContinue() async throws {
        let suiteName = "StudySessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        settings.studyMode = .multipleChoice
        let session = StudySession()
        session.start(store: store, settings: settings)
        let wordID = try XCTUnwrap(session.currentWordID)
        let word = try XCTUnwrap(store.word(id: wordID))
        let correctOption = try XCTUnwrap(
            session.options.first(where: \.isCorrect)
        )

        session.choose(
            correctOption,
            word: word,
            store: store,
            settings: settings
        )
        try await Task.sleep(for: .milliseconds(1_500))

        XCTAssertTrue(session.isLocked)
        XCTAssertTrue(session.isAnswerRevealed)
        XCTAssertEqual(session.currentWordID, wordID)

        session.continueAfterFeedback(store: store, settings: settings)
        XCTAssertNotEqual(session.currentWordID, wordID)
    }

    func testNotificationTargetLimitsInitialSessionSize() {
        let suiteName = "StudySessionTargetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = VocabularyStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let session = StudySession()

        session.start(
            store: store,
            settings: settings,
            targetCount: 13
        )

        XCTAssertEqual(session.totalCount, 13)
        XCTAssertNotNil(session.currentWordID)
    }

    private func moveAcrossThreeCards(
        session: StudySession,
        store: VocabularyStore,
        settings: AppSettings
    ) {
        session.continueAfterFeedback(store: store, settings: settings)
        for _ in 0..<3 {
            answerCurrent(
                correctly: true,
                session: session,
                store: store,
                settings: settings
            )
        }
    }

    private func answerCurrent(
        correctly: Bool,
        session: StudySession,
        store: VocabularyStore,
        settings: AppSettings
    ) {
        let currentID = try! XCTUnwrap(session.currentWordID)
        let currentWord = try! XCTUnwrap(store.word(id: currentID))
        session.selfAssess(
            word: currentWord,
            isCorrect: correctly,
            store: store,
            settings: settings
        )
        if correctly {
            session.continueAfterFeedback(store: store, settings: settings)
        }
    }
}

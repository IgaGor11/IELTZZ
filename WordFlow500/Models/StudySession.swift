import Foundation
import Observation

struct ChoiceOption: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
}

enum FeedbackTone: Equatable {
    case neutral
    case success
    case error
}

struct StudyFeedback: Equatable {
    let text: String
    let tone: FeedbackTone
}

@MainActor
@Observable
final class StudySession {
    private(set) var wordIDs: [Int] = []
    private(set) var position = 0
    private(set) var currentWordID: Int?
    private(set) var options: [ChoiceOption] = []
    private(set) var selectedOptionID: UUID?
    private(set) var isLocked = false
    private(set) var mistakesThisSession = 0
    private(set) var correctedMistakesThisSession = 0
    var typedAnswer = ""
    var isAnswerRevealed = false
    var feedback = StudyFeedback(
        text: "Начните с ответа или оцените себя вручную.",
        tone: .neutral
    )

    @ObservationIgnored private var transitionTask: Task<Void, Never>?
    @ObservationIgnored private var retryCountsByWordID: [Int: Int] = [:]
    @ObservationIgnored private var mistakesAwaitingCorrection = Set<Int>()

    var totalCount: Int { wordIDs.count }
    var displayedPosition: Int { currentWordID == nil ? totalCount : position + 1 }
    var isComplete: Bool { currentWordID == nil }

    func start(
        store: VocabularyStore,
        settings: AppSettings,
        targetCount: Int? = nil
    ) {
        transitionTask?.cancel()
        let candidates = SpacedRepetition.sessionCandidates(
            from: store.words,
            selectedList: settings.selectedList,
            onlyDifficult: settings.onlyDifficult
        )
        if let targetCount {
            wordIDs = Array(
                candidates.prefix(min(max(targetCount, 1), 5_000))
            ).map(\.id)
        } else {
            wordIDs = candidates.map(\.id)
        }
        position = 0
        currentWordID = wordIDs.first
        mistakesThisSession = 0
        correctedMistakesThisSession = 0
        retryCountsByWordID.removeAll()
        mistakesAwaitingCorrection.removeAll()
        prepareCurrent(store: store, settings: settings)
    }

    func restart(
        store: VocabularyStore,
        settings: AppSettings,
        targetCount: Int? = nil
    ) {
        start(
            store: store,
            settings: settings,
            targetCount: targetCount
        )
    }

    func refreshCurrent(store: VocabularyStore, settings: AppSettings) {
        guard currentWordID != nil, !isLocked else { return }
        prepareCurrent(store: store, settings: settings)
    }

    func showAnswer(for word: VocabularyWord, mode: StudyMode) {
        guard !isLocked else { return }
        isAnswerRevealed = true
        let answer = mode == .wordToTranslation || mode == .multipleChoice
            ? word.trimmedTranslation
            : word.word
        feedback = StudyFeedback(
            text: answer.isEmpty ? "Сначала добавьте перевод." : "Ответ: \(answer)",
            tone: .neutral
        )
    }

    func checkTypedAnswer(
        for word: VocabularyWord,
        mode: StudyMode,
        store: VocabularyStore,
        settings: AppSettings
    ) {
        guard !isLocked, !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let isCorrect = AnswerMatcher.matches(typedAnswer, word: word, mode: mode)
        grade(
            word: word,
            isCorrect: isCorrect,
            submittedAnswer: typedAnswer,
            store: store,
            settings: settings,
            delay: nil
        )
    }

    func selfAssess(
        word: VocabularyWord,
        isCorrect: Bool,
        store: VocabularyStore,
        settings: AppSettings
    ) {
        grade(
            word: word,
            isCorrect: isCorrect,
            submittedAnswer: nil,
            store: store,
            settings: settings,
            delay: nil
        )
    }

    func choose(
        _ option: ChoiceOption,
        word: VocabularyWord,
        store: VocabularyStore,
        settings: AppSettings
    ) {
        guard !isLocked else { return }
        selectedOptionID = option.id
        grade(
            word: word,
            isCorrect: option.isCorrect,
            submittedAnswer: option.text,
            store: store,
            settings: settings,
            delay: nil
        )
    }

    func cancelPendingTransition() {
        transitionTask?.cancel()
    }

    func continueAfterFeedback(
        store: VocabularyStore,
        settings: AppSettings
    ) {
        guard isLocked else { return }
        transitionTask?.cancel()
        advance(store: store, settings: settings)
    }

    func skipCurrent(store: VocabularyStore, settings: AppSettings) {
        guard !isLocked else { return }
        advance(store: store, settings: settings)
    }

    func optionState(_ option: ChoiceOption) -> FeedbackTone? {
        guard isLocked else { return nil }
        if option.isCorrect { return .success }
        if selectedOptionID == option.id { return .error }
        return nil
    }

    private func grade(
        word: VocabularyWord,
        isCorrect: Bool,
        submittedAnswer: String?,
        store: VocabularyStore,
        settings: AppSettings,
        delay: Duration?
    ) {
        guard !isLocked else { return }
        isLocked = true
        isAnswerRevealed = true
        let correctedPreviousMistake =
            isCorrect && mistakesAwaitingCorrection.remove(word.id) != nil
        if correctedPreviousMistake {
            correctedMistakesThisSession += 1
        }
        if !isCorrect {
            mistakesThisSession += 1
            mistakesAwaitingCorrection.insert(word.id)
            scheduleRetryIfNeeded(for: word.id)
        }
        store.grade(
            id: word.id,
            isCorrect: isCorrect,
            submittedAnswer: submittedAnswer,
            mode: settings.studyMode
        )
        let expectedAnswer = settings.studyMode == .wordToTranslation
            || settings.studyMode == .multipleChoice
            ? word.trimmedTranslation
            : word.word
        let feedbackText: String
        if correctedPreviousMistake {
            feedbackText = "Ошибка исправлена! Ответ закреплён."
        } else if isCorrect {
            feedbackText = "Верно! Следующее повторение запланировано."
        } else {
            let analysis = MistakeAnalyzer.message(
                submittedAnswer: submittedAnswer,
                expectedAnswer: expectedAnswer,
                mode: settings.studyMode
            )
            feedbackText =
                "\(analysis) Правильно: \(expectedAnswer). Повторим через несколько карточек."
        }
        feedback = StudyFeedback(
            text: feedbackText,
            tone: isCorrect ? .success : .error
        )

        transitionTask?.cancel()
        if let delay {
            transitionTask = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.advance(store: store, settings: settings)
            }
        }
    }

    private func advance(store: VocabularyStore, settings: AppSettings) {
        guard currentWordID != nil else { return }
        let nextPosition = position + 1
        if nextPosition < wordIDs.count {
            position = nextPosition
            currentWordID = wordIDs[nextPosition]
            prepareCurrent(store: store, settings: settings)
        } else {
            position = wordIDs.count
            currentWordID = nil
            isLocked = false
            options = []
            feedback = StudyFeedback(
                text: mistakesAwaitingCorrection.isEmpty
                    ? "Сессия завершена. Отличная работа!"
                    : "Сессия завершена. Нерешённые ошибки вернутся по расписанию повторения.",
                tone: mistakesAwaitingCorrection.isEmpty ? .success : .neutral
            )
        }
    }

    private func scheduleRetryIfNeeded(for wordID: Int) {
        let retryCount = retryCountsByWordID[wordID, default: 0]
        guard retryCount < 2 else { return }
        retryCountsByWordID[wordID] = retryCount + 1
        let retryPosition = min(position + 4, wordIDs.count)
        wordIDs.insert(wordID, at: retryPosition)
    }

    private func prepareCurrent(store: VocabularyStore, settings: AppSettings) {
        typedAnswer = ""
        selectedOptionID = nil
        isLocked = false
        isAnswerRevealed = settings.automaticallyShowsAnswer && settings.studyMode != .multipleChoice
        feedback = StudyFeedback(
            text: settings.onlyDifficult
                ? "Сессия только со сложными словами."
                : "Введите ответ или оцените себя.",
            tone: .neutral
        )

        guard
            settings.studyMode == .multipleChoice,
            let currentWordID,
            let word = store.word(id: currentWordID)
        else {
            options = []
            return
        }
        options = makeOptions(for: word, from: store.words)
        if options.isEmpty {
            feedback = StudyFeedback(
                text: "Для режима нужны переводы этого слова и ещё трёх разных слов.",
                tone: .neutral
            )
        }
    }

    private func makeOptions(for currentWord: VocabularyWord, from words: [VocabularyWord]) -> [ChoiceOption] {
        let correctText = currentWord.trimmedTranslation
        guard !correctText.isEmpty else { return [] }

        let normalizedCorrect = AnswerMatcher.normalized(correctText)
        var seen = Set([normalizedCorrect])
        var distractors: [String] = []
        let normalizedCurrentWord = AnswerMatcher.normalized(currentWord.word)

        for candidate in words.shuffled() where candidate.id != currentWord.id {
            guard AnswerMatcher.normalized(candidate.word) != normalizedCurrentWord else {
                continue
            }
            let text = candidate.trimmedTranslation
            let normalized = AnswerMatcher.normalized(text)
            guard !text.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            distractors.append(text)
            if distractors.count == 3 { break }
        }
        guard distractors.count == 3 else { return [] }

        return (
            [ChoiceOption(text: correctText, isCorrect: true)]
                + distractors.map { ChoiceOption(text: $0, isCorrect: false) }
        ).shuffled()
    }
}

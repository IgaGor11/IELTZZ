import Foundation

enum SpacedRepetition {
    static let intervalsInDays = [1, 2, 4, 8, 16, 32]

    struct Outcome: Equatable {
        let level: Int
        let nextReviewDate: Date
        var intervalDays: Int = 0
        var easeFactor: Double = 2.5
        var repetitions: Int = 0
        var lapses: Int = 0
    }

    static func outcome(
        currentLevel: Int,
        isCorrect: Bool,
        practicedAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        let word = VocabularyWord(id: 0, word: "", listNumber: 0, level: currentLevel)
        return outcome(currentWord: word, isCorrect: isCorrect, practicedAt: date, calendar: calendar)
    }

    /// Адаптивный SRS 0...10. Ур. 0–5: классическая таблица [1,2,4,8,16,32].
    /// Ур. 6–10: SM-2-подход (ease/repetitions/lapses), верно → +1 (макс. 10),
    /// ошибка → −1, но не ниже 6.
    static func outcome(
        currentWord: VocabularyWord?,
        isCorrect: Bool,
        practicedAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        let currentLevel = currentWord?.level ?? 0
        let currentEase = currentWord?.easeFactor ?? 2.5
        let currentReps = currentWord?.repetitions ?? 0
        let currentLapses = currentWord?.lapses ?? 0
        let startOfPracticeDay = calendar.startOfDay(for: date)

        if currentLevel <= 5 {
            let boundedLevel = min(max(currentLevel, 0), 5)
            let newLevel = isCorrect
                ? min(boundedLevel + 1, 5)
                : max(boundedLevel - 1, 0)
            let interval = intervalsInDays[newLevel]
            let nextDate = calendar.date(byAdding: .day, value: interval, to: startOfPracticeDay)
                ?? startOfPracticeDay
            return Outcome(
                level: newLevel,
                nextReviewDate: nextDate,
                intervalDays: interval,
                easeFactor: currentEase,
                repetitions: currentReps,
                lapses: isCorrect ? currentLapses : currentLapses + 1
            )
        }

        var newEase = currentEase
        var newReps = currentReps
        var newLapses = currentLapses
        if isCorrect {
            newEase = currentEase + 0.1
            newReps = currentReps + 1
        } else {
            newEase = max(1.3, currentEase - 0.2)
            newLapses = currentLapses + 1
            newReps = 0
        }
        let interval: Int
        switch newReps {
        case ...1: interval = 1
        case 2: interval = 3
        case 3: interval = 7
        case 4: interval = 14
        case 5: interval = 30
        default:
            interval = max(1, Int(30.0 * pow(newEase, Double(newReps - 5))))
        }
        let newLevel = isCorrect
            ? min(currentLevel + 1, Mastery.maxLevel)
            : max(6, currentLevel - 1)
        let nextDate = calendar.date(byAdding: .day, value: interval, to: startOfPracticeDay)
            ?? startOfPracticeDay
        return Outcome(
            level: newLevel,
            nextReviewDate: nextDate,
            intervalDays: interval,
            easeFactor: max(1.3, min(3.0, newEase)),
            repetitions: newReps,
            lapses: newLapses
        )
    }

    static func sessionCandidates(
        from words: [VocabularyWord],
        selectedList: Int,
        onlyDifficult: Bool,
        on date: Date = Date(),
        calendar: Calendar = .current,
        shuffled: Bool = true
    ) -> [VocabularyWord] {
        let filtered = words.filter { word in
            (selectedList == 0 || word.listNumber == selectedList)
                && (!onlyDifficult || word.isDifficult)
        }
        let today = calendar.startOfDay(for: date)
        let due = filtered.filter { word in
            guard let nextReviewDate = word.nextReviewDate else { return true }
            return calendar.startOfDay(for: nextReviewDate) <= today
        }
        var candidates = due.isEmpty ? filtered.filter { $0.level < 5 } : due
        // Surprise Test: выученные (Ур. 10) с просроченной проверкой — в сессию
        let surpriseDue = filtered.filter {
            SurpriseTest.shouldSurprise(word: $0, on: date, calendar: calendar)
        }
        if !surpriseDue.isEmpty {
            let knownIDs = Set(candidates.map(\.id))
            candidates += surpriseDue.filter { !knownIDs.contains($0.id) }
        }
        return shuffled ? candidates.shuffled() : candidates
    }
}

enum AnswerMatcher {
    static func matches(_ answer: String, word: VocabularyWord, mode: StudyMode) -> Bool {
        switch mode {
        case .wordToTranslation:
            let normalizedAnswer = normalized(answer)
            return acceptedTranslations(in: word.translation)
                .contains(normalizedAnswer)
        case .translationToWord:
            return normalized(answer) == normalized(word.word)
        case .spelling:
            return answer.trimmingCharacters(in: .whitespacesAndNewlines) == word.word
        case .multipleChoice:
            return false
        }
    }

    static func normalized(_ value: String) -> String {
        let stableLocale = Locale(identifier: "en_US_POSIX")
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: stableLocale)
    }

    private static func acceptedTranslations(in value: String) -> Set<String> {
        let separators = CharacterSet(charactersIn: ",;/")
        let variants = value
            .components(separatedBy: separators)
            .map(normalized)
            .filter { !$0.isEmpty }
        return Set(variants + [normalized(value)])
    }
}

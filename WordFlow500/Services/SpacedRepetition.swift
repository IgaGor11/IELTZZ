import Foundation

enum SpacedRepetition {
    static let intervalsInDays = [1, 2, 4, 8, 16, 32]

    struct Outcome: Equatable {
        let level: Int
        let nextReviewDate: Date
    }

    static func outcome(
        currentLevel: Int,
        isCorrect: Bool,
        practicedAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        let boundedLevel = min(max(currentLevel, 0), 5)
        let newLevel = isCorrect
            ? min(boundedLevel + 1, 5)
            : max(boundedLevel - 1, 0)
        let interval = intervalsInDays[newLevel]
        let startOfPracticeDay = calendar.startOfDay(for: date)
        let nextDate = calendar.date(byAdding: .day, value: interval, to: startOfPracticeDay)
            ?? startOfPracticeDay
        return Outcome(level: newLevel, nextReviewDate: nextDate)
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
        let candidates = due.isEmpty ? filtered.filter { $0.level < 5 } : due
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

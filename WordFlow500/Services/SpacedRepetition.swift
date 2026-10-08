import Foundation

enum SpacedRepetition {
    static let intervalsInDays = [1, 2, 4, 8, 16, 32]

    struct Outcome: Equatable {
        let level: Int
        let nextReviewDate: Date
        let intervalDays: Int
        let easeFactor: Double
        let repetitions: Int
        let lapses: Int
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

        let boundedLevelV1 = min(max(currentLevel, 0), 5)
        let newLevelV1 = isCorrect
            ? min(boundedLevelV1 + 1, 5)
            : max(boundedLevelV1 - 1, 0)
        let intervalV1 = intervalsInDays[newLevelV1]
        let startOfPracticeDay = calendar.startOfDay(for: date)
        let nextDateV1 = calendar.date(byAdding: .day, value: intervalV1, to: startOfPracticeDay)
            ?? startOfPracticeDay

        if currentLevel <= 5 {
            return Outcome(
                level: newLevelV1,
                nextReviewDate: nextDateV1,
                intervalDays: intervalV1,
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
        if newReps <= 1 {
            interval = 1
        } else if newReps == 2 {
            interval = 3
        } else if newReps == 3 {
            interval = 7
        } else if newReps == 4 {
            interval = 14
        } else if newReps == 5 {
            interval = 30
        } else {
            let base = 30.0 * pow(newEase, Double(newReps - 5))
            interval = max(1, Int(base))
        }

        let newLevelV2 = isCorrect
            ? min(currentLevel + 1, 10)
            : max(6, currentLevel - 1)

        let nextDate = calendar.date(byAdding: .day, value: interval, to: startOfPracticeDay) ?? startOfPracticeDay

        return Outcome(
            level: newLevelV2,
            nextReviewDate: nextDate,
            intervalDays: interval,
            easeFactor: max(1.3, min(3.0, newEase)),
            repetitions: newReps,
            lapses: newLapses
        )
    }

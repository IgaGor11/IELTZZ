import Foundation

enum SurpriseTest {
    static func shouldSurprise(
        word: VocabularyWord,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard word.level >= 10 else { return false }
        guard let last = word.lastSurpriseDate else { return true }
        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: date)
        ).day ?? Int.max
        return daysSince >= 7
    }

    static func applySurprise(
        to word: inout VocabularyWord,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        word.level = 6
        word.lastSurpriseDate = date
        let start = calendar.startOfDay(for: date)
        word.nextReviewDate = calendar.date(byAdding: .day, value: 1, to: start)
        word.intervalDays = 1
        word.repetitions = max(0, word.repetitions - 1)
    }
}

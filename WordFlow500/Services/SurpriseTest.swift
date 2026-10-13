import Foundation

/// Контрольная проверка выученных слов (Ур. 10): раз в 30 дней слово
/// возвращается в сессию. Забыл → падает на Ур. 6, вспомнил → остаётся на 10.
enum SurpriseTest {
    static let recheckIntervalDays = 30
    static let demotionLevel = 6

    static func shouldSurprise(
        word: VocabularyWord,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard word.level >= Mastery.masteredLevel else { return false }
        guard let last = word.lastSurpriseDate ?? word.masteredAt else { return true }
        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: date)
        ).day ?? Int.max
        return daysSince >= recheckIntervalDays
    }

    static func applySurprise(
        to word: inout VocabularyWord,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        word.level = demotionLevel
        word.lastSurpriseDate = date
        let start = calendar.startOfDay(for: date)
        word.nextReviewDate = calendar.date(byAdding: .day, value: 1, to: start)
        word.intervalDays = 1
        word.repetitions = max(0, word.repetitions - 1)
    }

    static func markRechecked(
        _ word: inout VocabularyWord,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        word.lastSurpriseDate = date
        let start = calendar.startOfDay(for: date)
        word.nextReviewDate = calendar.date(byAdding: .day, value: recheckIntervalDays, to: start)
        word.intervalDays = recheckIntervalDays
    }
}

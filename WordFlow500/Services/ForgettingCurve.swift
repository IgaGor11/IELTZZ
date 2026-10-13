import Foundation

/// Кривая забывания по данным SRS: средняя удерживаемость слов
/// через d дней. Период полураспада ≈ интервал повторения слова.
enum ForgettingCurve {
    static let horizonDays = 30

    static func points(for words: [VocabularyWord]) -> [(day: Int, retention: Double)] {
        guard !words.isEmpty else {
            return (0...horizonDays).map { ($0, 0) }
        }
        return (0...horizonDays).map { day in
            let total = words.reduce(0.0) { $0 + retention($1, after: day) }
            return (day, total / Double(words.count))
        }
    }

    static func retention(_ word: VocabularyWord, after days: Int) -> Double {
        if Mastery.isMastered(word) {
            return max(0.75, 0.99 - Double(days) * 0.004)
        }
        let halfLife = max(1.0, Double(max(word.intervalDays, 1)))
        return pow(0.5, Double(days) / halfLife)
    }
}

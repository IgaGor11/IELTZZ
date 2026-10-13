import Foundation

/// Уровни 0...10 и геймификация IELTS Band.
/// Ур. 10 «Выучено»: 5 правильных подряд с гэпом ≥ 7 дней + минимум
/// 2 корректных предложения (contextSentencesOK, растёт только через AI-проверку).
enum Mastery {
    static let maxLevel = 10
    static let masteredLevel = 10
    static let requiredStreak = 5
    static let requiredGapDays = 7
    static let requiredSentences = 2

    /// Проверка критериев Ур. 10 по истории попыток.
    static func meetsMasteryCriteria(
        _ word: VocabularyWord,
        calendar: Calendar = .current
    ) -> Bool {
        guard word.contextSentencesOK >= requiredSentences else { return false }
        let correct = (word.attempts ?? []).suffix(requiredStreak)
        guard correct.count == requiredStreak, correct.allSatisfy(\.correct) else {
            return false
        }
        let days = correct.map { calendar.startOfDay(for: $0.attemptedAt) }
        for index in days.indices.dropFirst() {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            guard gap >= requiredGapDays else { return false }
        }
        return true
    }

    static func isMastered(_ word: VocabularyWord) -> Bool {
        word.level >= masteredLevel
    }

    /// Виртуальный IELTS Band: +0.1 за каждые 10 выученных, база 6.0, потолок 9.0.
    /// 100 выученных → 7.0, 200 → 8.0.
    static func bandScore(masteredCount: Int) -> Double {
        min(9.0, 6.0 + Double(masteredCount) / 100.0)
    }

    static func bandProgress(masteredCount: Int) -> (current: Double, next: Double, progress: Double) {
        let current = bandScore(masteredCount: masteredCount)
        let next = min(9.0, (floor(current * 10) + 1) / 10)
        let progress = next > current ? (current * 10 - floor(current * 10)) : 1
        return (current, next, progress)
    }
}

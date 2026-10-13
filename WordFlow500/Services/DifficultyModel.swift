import Foundation

/// Оценка проблемности слова 0...1: точность последних попыток,
/// средняя задержка ответа, срывы (lapses). Проблемное: точность < 95%.
enum DifficultyModel {
    static let problemAccuracyThreshold = 0.95

    static func score(
        attempts: [AttemptRecord],
        lapses: Int,
        correctStreak: Int
    ) -> Double {
        let recent = Array(attempts.suffix(20))
        let total = max(1.0, Double(recent.count))
        let accuracy = recent.reduce(0.0) { $0 + ($1.correct ? 1.0 : 0.0) } / total
        let avgLatency = recent.reduce(0.0) { $0 + $1.latency } / total
        let lapsePenalty = min(0.4, Double(lapses) * 0.05)
        let streakBonus = min(0.2, Double(correctStreak) * 0.01)
        let latencyPenalty = min(0.2, max(0, avgLatency - 5.0) / 60.0)
        let raw = (1.0 - accuracy) + lapsePenalty + latencyPenalty - streakBonus
        return max(0.0, min(1.0, raw))
    }

    static func recentAccuracy(_ word: VocabularyWord, limit: Int = 20) -> Double? {
        let recent = Array((word.attempts ?? []).suffix(limit))
        guard !recent.isEmpty else { return nil }
        return Double(recent.filter(\.correct).count) / Double(recent.count)
    }

    static func isProblem(_ word: VocabularyWord) -> Bool {
        if let accuracy = recentAccuracy(word) {
            return accuracy < problemAccuracyThreshold
        }
        return word.incorrectCount > 0
            && Double(word.incorrectCount) / Double(max(1, word.incorrectCount + word.correctCount)) > 0.05
    }
}

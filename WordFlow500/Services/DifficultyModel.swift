import Foundation

enum DifficultyModel {
    static func score(
        attempts: [AttemptRecord],
        lapses: Int,
        correctStreak: Int
    ) -> Double {
        let recentAttempts = Array(attempts.suffix(20))
        let totalRecent = max(1.0, Double(recentAttempts.count))
        let accuracy = recentAttempts.reduce(0.0) { $0 + ($1.correct ? 1.0 : 0.0) } / totalRecent
        let avgLatency = recentAttempts.reduce(0.0) { $0 + $1.latency } / totalRecent

        let lapsePenalty = min(0.4, Double(lapses) * 0.05)
        let streakBonus = min(0.2, Double(correctStreak) * 0.01)
        let latencyPenalty = min(0.2, max(0, (avgLatency - 5.0)) / 60.0)

        let raw = (1.0 - accuracy) + lapsePenalty + latencyPenalty - streakBonus
        return max(0.0, min(1.0, raw))
    }
}

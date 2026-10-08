import Foundation

enum ForgettingCurve {
    static func retentionInterval(easeFactor: Double, desiredRetention: Double = 0.95) -> Int {
        let clampedEase = max(1.3, easeFactor)
        let interval = Int(pow(Double(1.0 + clampedEase / 10.0), log(desiredRetention / (1.0 - desiredRetention)) * (-0.1)))
        return max(1, interval)
    }

    static func shouldReview(
        lastReviewDate: Date?,
        intervalDays: Int,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastReviewDate else { return true }
        guard intervalDays > 0 else { return true }
        let next = calendar.date(byAdding: .day, value: intervalDays, to: calendar.startOfDay(for: lastReviewDate))
        return next.map { calendar.startOfDay(for: $0) <= calendar.startOfDay(for: date) } ?? true
    }
}

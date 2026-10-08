import Foundation

@MainActor
final class AIBudget: ObservableObject {
    private enum Key {
        static let dailyCount = "ai.budget.dailyCount"
        static let lastDate = "ai.budget.lastDate"
    }

    private let defaults: UserDefaults
    private let limit: Int

    @Published private(set) var used: Int = 0
    @Published private(set) var remaining: Int = 600

    init(defaults: UserDefaults = .standard, limit: Int = 600) {
        self.defaults = defaults
        self.limit = limit
        resetIfNeeded()
    }

    var canSpend: Bool {
        resetIfNeeded()
        return used < limit
    }

    func recordSpend(_ amount: Int = 1) {
        guard amount > 0 else { return }
        resetIfNeeded()
        used = min(limit, used + amount)
        remaining = max(0, limit - used)
        defaults.set(used, forKey: Key.dailyCount)
    }

    private func resetIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate: Date? = defaults.object(forKey: Key.lastDate) as? Date

        if lastDate == nil || calendar.startOfDay(for: lastDate!) != today {
            used = 0
            remaining = limit
            defaults.set(0, forKey: Key.dailyCount)
            defaults.set(today, forKey: Key.lastDate)
            return
        }

        used = min(limit, defaults.integer(forKey: Key.dailyCount))
        remaining = max(0, limit - used)
    }
}

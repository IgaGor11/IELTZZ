import Foundation
import Combine

final class AIBudget: ObservableObject {
    @Published private(set) var used: Int = 0
    @Published private(set) var remaining: Int = 600

    private let dailyLimit: Int

    init(dailyLimit: Int = 600) {
        self.dailyLimit = dailyLimit
        self.remaining = dailyLimit
    }

    func canSpend(_ amount: Int = 1) -> Bool {
        remaining >= amount
    }

    func spend(_ amount: Int = 1) {
        guard canSpend(amount) else { return }
        used += amount
        remaining = max(0, dailyLimit - used)
    }

    func reset() {
        used = 0
        remaining = dailyLimit
    }
}
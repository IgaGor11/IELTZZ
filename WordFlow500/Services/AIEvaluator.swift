import Foundation
import Combine

@MainActor
final class AIEvaluator: ObservableObject {
    private let client: AIAPIClient
    private let budget: AIBudget

    init(client: AIAPIClient = AIAPIClient(), budget: AIBudget = AIBudget()) {
        self.client = client
        self.budget = budget
    }

    func evaluate(sentence: String) async throws -> String? {
        guard budget.canSpend() else { return nil }
        // Simulated evaluation - in production would call client.post
        budget.spend()
        return "Sentence evaluated successfully"
    }
}
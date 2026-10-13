import Foundation
import Combine

final class AIEnricher: ObservableObject {
    private let client: AIAPIClient
    private let budget: AIBudget
    private let cache: AICache

    init(client: AIAPIClient = AIAPIClient(), budget: AIBudget = AIBudget(), cache: AICache = AICache()) {
        self.client = client
        self.budget = budget
        self.cache = cache
    }

    func enrich(word: String, translation: String?) async throws -> [String: String]? {
        guard budget.canSpend() else { return nil }
        let key = "enrich:\(word)"
        if let cached = cache.get(key),
           let decoded = try? JSONDecoder().decode([String: String].self, from: cached) {
            return decoded
        }
        // Simulated response for build - in production would call client.post
        let response: [String: String] = [
            "translation": translation ?? "",
            "synonyms": "",
            "collocations": ""
        ]
        budget.spend()
        if let encoded = try? JSONEncoder().encode(response) {
            cache.set(encoded, for: key)
        }
        return response
    }
}
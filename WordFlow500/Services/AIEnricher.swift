import Foundation
import Combine

/// Обогащение карточки: синонимы, коллокации, регистр, тема, примеры.
/// Идёт через прокси-воркер (ключ только там), модель по умолчанию —
/// бесплатная Nemotron. Офлайн/ошибка → nil, база остаётся бесплатной.
final class AIEnricher: ObservableObject {
    private let client: AIAPIClient
    private let budget: AIBudget
    private let cache: AICache

    init(client: AIAPIClient = AIAPIClient(), budget: AIBudget = AIBudget(), cache: AICache = AICache()) {
        self.client = client
        self.budget = budget
        self.cache = cache
    }

    func enrich(word: String, translation: String?) async -> AIWordEnrichment? {
        let key = "enrich:\(word.lowercased())"
        if let cached = cache.get(key),
           let decoded = try? JSONDecoder().decode(AIWordEnrichment.self, from: cached)
        {
            return decoded
        }
        guard budget.canSpend() else { return nil }
        do {
            let response: AIWordEnrichment = try await client.post(
                "enrich",
                body: AIEnrichRequest(words: [AIEnrichWord(word: word, translation: translation)])
            )
            budget.spend()
            if let encoded = try? JSONEncoder().encode(response) {
                cache.set(encoded, for: key)
            }
            return response
        } catch {
            return nil
        }
    }

    func smartCard(rawWord: String) async -> AISmartCardResponse? {
        guard budget.canSpend() else { return nil }
        do {
            let response: AISmartCardResponse = try await client.post(
                "smart-card",
                body: AISmartCardRequest(rawWord: rawWord)
            )
            budget.spend()
            return response
        } catch {
            return nil
        }
    }
}

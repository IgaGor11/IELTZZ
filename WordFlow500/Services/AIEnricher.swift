import Foundation

@MainActor
final class AIEnricher: ObservableObject {
    private let api: AIAPIClient
    private let cache: AICache
    private let budget: AIBudget

    init(api: AIAPIClient, cache: AICache, budget: AIBudget) {
        self.api = api
        self.cache = cache
        self.budget = budget
    }

    func enrichIfNeeded(_ word: VocabularyWord) async -> VocabularyWord? {
        if word.isAIEnriched { return nil }
        if !budget.canSpend { return nil }
        if let cached = cache.enrichment(for: word.word) {
            return apply(cached, to: word)
        }
        do {
            let results = try await api.enrich([AIEnrichWord(word: word.word, translation: word.translation)])
            if let enriched = results?[word.word] {
                budget.recordSpend()
                cache.store(enriched, for: word.word)
                return apply(enriched, to: word)
            }
        } catch {
        }
        return nil
    }

    private func apply(_ enriched: AIWordEnrichment, to word: VocabularyWord) -> VocabularyWord {
        var updated = word
        updated.synonyms = enriched.synonyms
        updated.collocations = enriched.collocations
        updated.registerTags = enriched.registerTags
        updated.topic = enriched.topic
        updated.aiExamples = enriched.aiExamples
        updated.isAIEnriched = true
        return updated
    }
}

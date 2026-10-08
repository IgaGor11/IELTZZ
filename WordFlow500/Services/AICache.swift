import Foundation

@MainActor
final class AICache: ObservableObject {
    private struct CachedEnrichment: Codable {
        let data: AIWordEnrichment
        let date: Date
    }

    private let defaults: UserDefaults
    private let ttl: TimeInterval

    init(defaults: UserDefaults = .standard, ttl: TimeInterval = 7 * 24 * 3600) {
        self.defaults = defaults
        self.ttl = ttl
    }

    private func key(for word: String) -> String {
        let normalized = word.lowercased()
        return "ai.cache.enrich.\(normalized.hashValue)"
    }

    func enrichment(for word: String) -> AIWordEnrichment? {
        let keyValue = key(for: word)
        guard let data = defaults.data(forKey: keyValue),
              let cached = try? JSONDecoder().decode(CachedEnrichment.self, from: data) else { return nil }
        if Date().timeIntervalSince(cached.date) > ttl {
            defaults.removeObject(forKey: keyValue)
            return nil
        }
        return cached.data
    }

    func store(_ enrichment: AIWordEnrichment, for word: String) {
        let keyValue = key(for: word)
        let cached = CachedEnrichment(data: enrichment, date: Date())
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: keyValue)
        }
    }
}

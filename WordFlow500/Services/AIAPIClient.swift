import Foundation

@MainActor
final class AIAPIClient: ObservableObject {
    private let baseURL: URL
    private let secret: String?
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://lifeos.pifagoryy.workers.dev/api/ai")!, secret: String? = nil) {
        self.baseURL = baseURL
        self.secret = secret
        self.session = URLSession(configuration: .default)
    }

    private func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: String = "POST",
        body: B? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NSError(domain: "AI", code: 0) }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            throw NSError(domain: "AI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func enrich(_ words: [AIEnrichWord]) async throws -> [String: AIWordEnrichment]? {
        let req = AIEnrichRequest(words: words)
        struct Response: Codable { let results: [String: AIWordEnrichment]? }
        let res: Response = try await request("enrich", body: req)
        return res.results
    }

    func context(word: String, translation: String?) async throws -> [String] {
        let req = AIContextRequest(word: word, translation: translation)
        let res: AIContextResponse = try await request("context", body: req)
        return res.sentences ?? []
    }

    func checkExample(word: String, sentence: String) async throws -> (ok: Bool, suggestion: String?) {
        let req = AICheckExampleRequest(word: word, sentence: sentence)
        let res: AICheckExampleResponse = try await request("check-example", body: req)
        return (res.ok ?? true, res.suggestion)
    }

    func writing(paragraph: String, targetWords: [String]? = nil) async throws -> [String] {
        let req = AIWritingRequest(paragraph: paragraph, targetWords: targetWords)
        let res: AIWritingResponse = try await request("writing", body: req)
        return res.suggestions ?? []
    }

    func speaking(word: String, text: String?) async throws -> String? {
        let req = AISpeakingRequest(word: word, text: text)
        let res: AISpeakingResponse = try await request("speaking", body: req)
        return res.feedback
    }

    func smartCard(_ rawWord: String) async throws -> (explanation: String?, examples: [String]?) {
        let req = AISmartCardRequest(rawWord: rawWord)
        let res: AISmartCardResponse = try await request("smart-card", body: req)
        return (res.explanation, res.examples)
    }
}

import Foundation

@MainActor
final class AIEvaluator: ObservableObject {
    private let api: AIAPIClient

    init(api: AIAPIClient) {
        self.api = api
    }

    func checkWriting(paragraph: String, targetWords: [String]) async throws -> [String] {
        return try await api.writing(paragraph: paragraph, targetWords: targetWords)
    }

    func checkSpeaking(word: String, text: String) async throws -> String? {
        return try await api.speaking(word: word, text: text)
    }

    func checkExample(word: String, sentence: String) async throws -> (ok: Bool, suggestion: String?) {
        return try await api.checkExample(word: word, sentence: sentence)
    }
}

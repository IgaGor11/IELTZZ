import Foundation
import Combine

/// Проверка примеров пользователя, Writing и Speaking Booster.
/// Ошибки сети/бюджета → nil, приложение работает офлайн.
final class AIEvaluator: ObservableObject {
    private let client: AIAPIClient
    private let budget: AIBudget

    init(client: AIAPIClient = AIAPIClient(), budget: AIBudget = AIBudget()) {
        self.client = client
        self.budget = budget
    }

    func checkExample(word: String, sentence: String) async -> AICheckExampleResponse? {
        guard budget.canSpend() else { return nil }
        do {
            let response: AICheckExampleResponse = try await client.post(
                "check-example",
                body: AICheckExampleRequest(word: word, sentence: sentence)
            )
            budget.spend()
            return response
        } catch {
            return nil
        }
    }

    func evaluateWriting(paragraph: String, targetWords: [String]) async -> [String] {
        guard budget.canSpend() else { return [] }
        do {
            let response: AIWritingResponse = try await client.post(
                "writing",
                body: AIWritingRequest(paragraph: paragraph, targetWords: targetWords)
            )
            budget.spend()
            return response.suggestions ?? []
        } catch {
            return []
        }
    }

    func evaluateSpeaking(word: String, text: String) async -> String? {
        guard budget.canSpend() else { return nil }
        do {
            let response: AISpeakingResponse = try await client.post(
                "speaking",
                body: AISpeakingRequest(word: word, text: text)
            )
            budget.spend()
            return response.feedback
        } catch {
            return nil
        }
    }
}

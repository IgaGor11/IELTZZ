import Foundation

/// Модель по умолчанию — бесплатная. Ключ хранится только на прокси-воркере,
/// в приложении секретов нет: без сети все AI-функции тихо возвращают nil.
enum AIModel {
    /// OpenRouter, бесплатно, большой контекст.
    static let `default` = "nvidia/nemotron-3.5-lightning"
    /// Запасной вариант через тот же прокси.
    static let fallback = "gemini-2.0-flash"
}

struct AIWordEnrichment: Codable, Sendable {
    var translationTags: [String]?
    var synonyms: [String]?
    var collocations: [String]?
    var registerTags: [String]?
    var topic: String?
    var aiExamples: [String]?
}

struct AIEnrichRequest: Codable, Sendable {
    var words: [AIEnrichWord]
    var model: String

    init(words: [AIEnrichWord], model: String = AIModel.default) {
        self.words = words
        self.model = model
    }
}

struct AIEnrichWord: Codable, Sendable {
    var word: String
    var translation: String?
}

struct AICheckExampleRequest: Codable, Sendable {
    var word: String
    var sentence: String
    var model: String

    init(word: String, sentence: String, model: String = AIModel.default) {
        self.word = word
        self.sentence = sentence
        self.model = model
    }
}

struct AICheckExampleResponse: Codable, Sendable {
    var ok: Bool?
    var suggestion: String?
}

struct AIWritingRequest: Codable, Sendable {
    var paragraph: String
    var targetWords: [String]?
    var model: String

    init(paragraph: String, targetWords: [String]? = nil, model: String = AIModel.default) {
        self.paragraph = paragraph
        self.targetWords = targetWords
        self.model = model
    }
}

struct AIWritingResponse: Codable, Sendable {
    var suggestions: [String]?
}

struct AISpeakingRequest: Codable, Sendable {
    var word: String
    var text: String?
    var model: String

    init(word: String, text: String? = nil, model: String = AIModel.default) {
        self.word = word
        self.text = text
        self.model = model
    }
}

struct AISpeakingResponse: Codable, Sendable {
    var feedback: String?
}

struct AISmartCardRequest: Codable, Sendable {
    var rawWord: String
    var model: String

    init(rawWord: String, model: String = AIModel.default) {
        self.rawWord = rawWord
        self.model = model
    }
}

struct AISmartCardResponse: Codable, Sendable {
    var word: String?
    var translation: String?
    var explanation: String?
    var examples: [String]?
    var synonyms: [String]?
    var collocations: [String]?
}

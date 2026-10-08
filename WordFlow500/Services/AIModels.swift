import Foundation

struct AIWordEnrichment: Codable, Sendable {
    let translationTags: [String]?
    let synonyms: [String]?
    let collocations: [String]?
    let registerTags: [String]?
    let topic: String?
    let aiExamples: [String]?
}

struct AIEnrichRequest: Codable, Sendable {
    let words: [AIEnrichWord]
}

struct AIEnrichWord: Codable, Sendable {
    let word: String
    let translation: String?
}

struct AIContextRequest: Codable, Sendable {
    let word: String
    let translation: String?
}

struct AIContextResponse: Codable, Sendable {
    let sentences: [String]?
}

struct AICheckExampleRequest: Codable, Sendable {
    let word: String
    let sentence: String
}

struct AICheckExampleResponse: Codable, Sendable {
    let ok: Bool?
    let suggestion: String?
}

struct AIWritingRequest: Codable, Sendable {
    let paragraph: String
    let targetWords: [String]?
}

struct AIWritingResponse: Codable, Sendable {
    let suggestions: [String]?
}

struct AISpeakingRequest: Codable, Sendable {
    let word: String
    let text: String?
}

struct AISpeakingResponse: Codable, Sendable {
    let feedback: String?
}

struct AISmartCardRequest: Codable, Sendable {
    let rawWord: String
}

struct AISmartCardResponse: Codable, Sendable {
    let explanation: String?
    let examples: [String]?
}

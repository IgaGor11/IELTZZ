import Foundation

struct VocabularyWord: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    var word: String
    var listNumber: Int
    var translation: String
    var example: String
    var level: Int
    var nextReviewDate: Date?
    var associationDrawing: Data?
    var correctCount: Int
    var incorrectCount: Int
    var isDifficult: Bool
    var lastPracticeDate: Date?
    var mistakeHistory: [MistakeRecord]?

    init(
        id: Int,
        word: String,
        listNumber: Int,
        translation: String = "",
        example: String = "",
        level: Int = 0,
        nextReviewDate: Date? = nil,
        associationDrawing: Data? = nil,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        isDifficult: Bool = false,
        lastPracticeDate: Date? = nil,
        mistakeHistory: [MistakeRecord]? = nil
    ) {
        self.id = id
        self.word = word
        self.listNumber = listNumber
        self.translation = translation
        self.example = example
        self.level = level
        self.nextReviewDate = nextReviewDate
        self.associationDrawing = associationDrawing
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.isDifficult = isDifficult
        self.lastPracticeDate = lastPracticeDate
        self.mistakeHistory = mistakeHistory
    }

    var trimmedTranslation: String {
        translation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasTranslation: Bool {
        !trimmedTranslation.isEmpty
    }

    var recentMistakes: [MistakeRecord] {
        mistakeHistory ?? []
    }
}

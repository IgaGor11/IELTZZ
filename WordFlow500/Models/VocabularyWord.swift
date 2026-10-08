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
    var synonyms: [String]?
    var collocations: [String]?
    var registerTags: [String]?
    var topic: String?
    var aiExamples: [String]?
    var isAIEnriched: Bool
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var lapses: Int
    var attempts: [AttemptRecord]?
    var difficultScore: Double
    var learnerCorrectStreak: Int
    var contextSentencesOK: Int
    var lastSurpriseDate: Date?

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
        mistakeHistory: [MistakeRecord]? = nil,
        synonyms: [String]? = nil,
        collocations: [String]? = nil,
        registerTags: [String]? = nil,
        topic: String? = nil,
        aiExamples: [String]? = nil,
        isAIEnriched: Bool = false,
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        lapses: Int = 0,
        attempts: [AttemptRecord]? = nil,
        difficultScore: Double = 0.0,
        learnerCorrectStreak: Int = 0,
        contextSentencesOK: Int = 0,
        lastSurpriseDate: Date? = nil
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
        self.synonyms = synonyms
        self.collocations = collocations
        self.registerTags = registerTags
        self.topic = topic
        self.aiExamples = aiExamples
        self.isAIEnriched = isAIEnriched
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.lapses = lapses
        self.attempts = attempts
        self.difficultScore = difficultScore
        self.learnerCorrectStreak = learnerCorrectStreak
        self.contextSentencesOK = contextSentencesOK
        self.lastSurpriseDate = lastSurpriseDate
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

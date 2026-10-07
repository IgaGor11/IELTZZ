import Foundation

enum StudyMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case wordToTranslation
    case translationToWord
    case multipleChoice
    case spelling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wordToTranslation:
            "Слово → перевод"
        case .translationToWord:
            "Перевод → слово"
        case .multipleChoice:
            "Выбор из 4"
        case .spelling:
            "Написание по буквам"
        }
    }

    var answerPlaceholder: String {
        switch self {
        case .wordToTranslation:
            "Введите перевод"
        case .translationToWord, .spelling:
            "Введите английское слово"
        case .multipleChoice:
            ""
        }
    }
}

struct LearningStatistics: Equatable, Sendable {
    let totalWords: Int
    let learnedWords: Int
    let translatedWords: Int
    let difficultWords: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    let practicedToday: Int

    var accuracy: Double {
        let totalAnswers = correctAnswers + incorrectAnswers
        guard totalAnswers > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalAnswers) * 100
    }
}


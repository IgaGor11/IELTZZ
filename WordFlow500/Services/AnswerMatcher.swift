import Foundation

enum AnswerMatcher {
    static func matches(_ answer: String, word: VocabularyWord, mode: StudyMode) -> Bool {
        switch mode {
        case .wordToTranslation:
            let normalizedAnswer = normalized(answer)
            return acceptedTranslations(in: word.translation)
                .contains(normalizedAnswer)
        case .translationToWord:
            return normalized(answer) == normalized(word.word)
        case .spelling:
            return answer.trimmingCharacters(in: .whitespacesAndNewlines) == word.word
        case .multipleChoice:
            return false
        }
    }

    static func normalized(_ value: String) -> String {
        let stableLocale = Locale(identifier: "en_US_POSIX")
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: stableLocale)
    }

    private static func acceptedTranslations(in value: String) -> Set<String> {
        let separators = CharacterSet(charactersIn: ",;/")
        let variants = value
            .components(separatedBy: separators)
            .map(normalized)
            .filter { !$0.isEmpty }
        return Set(variants + [normalized(value)])
    }
}

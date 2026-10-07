import Foundation

enum MistakeAnalyzer {
    static func message(
        submittedAnswer: String?,
        expectedAnswer: String,
        mode: StudyMode
    ) -> String {
        guard
            let submittedAnswer,
            !submittedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "Слово отмечено для дополнительного повторения."
        }

        if mode == .multipleChoice {
            return "Выбран другой вариант — сравните его с правильным."
        }

        let submitted = AnswerMatcher.normalized(submittedAnswer)
        let expectedVariants = expectedAnswer
            .components(separatedBy: CharacterSet(charactersIn: ",;/"))
            .map(AnswerMatcher.normalized)
            .filter { !$0.isEmpty }

        if
            mode == .spelling,
            submitted == AnswerMatcher.normalized(expectedAnswer)
        {
            return "Написание близкое, но в этом режиме важны точный регистр и знаки."
        }

        let closestDistance = expectedVariants
            .map { levenshteinDistance(submitted, $0) }
            .min() ?? expectedAnswer.count
        let shortestLength = expectedVariants.map(\.count).min() ?? expectedAnswer.count
        let closeAnswerThreshold = max(1, min(3, shortestLength / 4))

        if closestDistance <= closeAnswerThreshold {
            return "Ответ близок к правильному — проверьте буквы или форму слова."
        }

        return "Сравните свой ответ с правильным и изучите примеры на карточке."
    }

    private static func levenshteinDistance(_ source: String, _ target: String) -> Int {
        let sourceCharacters = Array(source)
        let targetCharacters = Array(target)
        guard !sourceCharacters.isEmpty else { return targetCharacters.count }
        guard !targetCharacters.isEmpty else { return sourceCharacters.count }

        var previous = Array(0...targetCharacters.count)
        for (sourceIndex, sourceCharacter) in sourceCharacters.enumerated() {
            var current = [sourceIndex + 1]
            current.reserveCapacity(targetCharacters.count + 1)
            for (targetIndex, targetCharacter) in targetCharacters.enumerated() {
                current.append(
                    min(
                        current[targetIndex] + 1,
                        previous[targetIndex + 1] + 1,
                        previous[targetIndex]
                            + (sourceCharacter == targetCharacter ? 0 : 1)
                    )
                )
            }
            previous = current
        }
        return previous[targetCharacters.count]
    }
}

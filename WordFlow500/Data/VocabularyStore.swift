    func grade(
        id: Int,
        isCorrect: Bool,
        submittedAnswer: String? = nil,
        mode: StudyMode = .wordToTranslation,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        mutateWord(id: id) { word in
            let outcome = SpacedRepetition.outcome(
                currentWord: word,
                isCorrect: isCorrect,
                practicedAt: date,
                calendar: calendar
            )
            let latency: TimeInterval = 0
            word.attempts = (word.attempts ?? []) + [
                AttemptRecord(attemptedAt: date, latency: latency, correct: isCorrect, mode: mode)
            ]
            word.level = outcome.level
            word.nextReviewDate = outcome.nextReviewDate
            word.intervalDays = outcome.intervalDays
            word.easeFactor = outcome.easeFactor
            word.repetitions = outcome.repetitions
            word.lapses = outcome.lapses
            word.difficultScore = DifficultyModel.score(
                attempts: word.attempts ?? [],
                lapses: word.lapses,
                correctStreak: word.learnerCorrectStreak
            )
            if isCorrect {
                word.learnerCorrectStreak += 1
            } else {
                word.learnerCorrectStreak = 0
            }
            word.lastPracticeDate = date
            if isCorrect {
                word.correctCount += 1
                if var history = word.mistakeHistory {
                    for index in history.indices where
                        history[index].correctedAt == nil
                            && history[index].mode == mode
                    {
                        history[index].correctedAt = date
                    }
                    word.mistakeHistory = history
                }
            } else {
                word.incorrectCount += 1
                let expectedAnswer = Self.expectedAnswer(for: word, mode: mode)
                var history = word.mistakeHistory ?? []
                history.append(
                    MistakeRecord(
                        submittedAnswer: submittedAnswer?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .nilIfEmpty,
                        expectedAnswer: expectedAnswer,
                        mode: mode,
                        practicedAt: date,
                        analysis: MistakeAnalyzer.message(
                            submittedAnswer: submittedAnswer,
                            expectedAnswer: expectedAnswer,
                            mode: mode
                        )
                    )
                )
                word.mistakeHistory = Array(history.suffix(20))
            }
        }
        persistMistakes(for: id)
    }

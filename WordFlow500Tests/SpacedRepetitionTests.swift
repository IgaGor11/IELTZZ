import XCTest
@testable import WordFlow500

final class SpacedRepetitionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var referenceDate: Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 24,
            hour: 15
        ).date!
    }

    func testCorrectTransitionsUseIntervalOfNewLevel() {
        let expected = [
            (old: 0, new: 1, days: 2),
            (old: 1, new: 2, days: 4),
            (old: 2, new: 3, days: 8),
            (old: 3, new: 4, days: 16),
            (old: 4, new: 5, days: 32),
            (old: 5, new: 5, days: 32)
        ]

        for transition in expected {
            let outcome = SpacedRepetition.outcome(
                currentLevel: transition.old,
                isCorrect: true,
                practicedAt: referenceDate,
                calendar: calendar
            )
            XCTAssertEqual(outcome.level, transition.new)
            XCTAssertEqual(
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: referenceDate),
                    to: outcome.nextReviewDate
                ).day,
                transition.days
            )
        }
    }

    func testIncorrectTransitionsUseIntervalOfNewLevel() {
        let expected = [
            (old: 0, new: 0, days: 1),
            (old: 1, new: 0, days: 1),
            (old: 2, new: 1, days: 2),
            (old: 3, new: 2, days: 4),
            (old: 4, new: 3, days: 8),
            (old: 5, new: 4, days: 16)
        ]

        for transition in expected {
            let outcome = SpacedRepetition.outcome(
                currentLevel: transition.old,
                isCorrect: false,
                practicedAt: referenceDate,
                calendar: calendar
            )
            XCTAssertEqual(outcome.level, transition.new)
            XCTAssertEqual(
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: referenceDate),
                    to: outcome.nextReviewDate
                ).day,
                transition.days
            )
        }
    }

    func testSessionUsesDueWordsBeforeFallback() {
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let words = [
            VocabularyWord(id: 1, word: "due", listNumber: 1, level: 2, nextReviewDate: yesterday),
            VocabularyWord(id: 2, word: "future", listNumber: 1, level: 1, nextReviewDate: tomorrow),
            VocabularyWord(id: 3, word: "new", listNumber: 2)
        ]

        let result = SpacedRepetition.sessionCandidates(
            from: words,
            selectedList: 1,
            onlyDifficult: false,
            on: referenceDate,
            calendar: calendar,
            shuffled: false
        )
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testSessionFallbackAndDifficultFilter() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let words = [
            VocabularyWord(
                id: 1,
                word: "hard",
                listNumber: 1,
                level: 4,
                nextReviewDate: tomorrow,
                isDifficult: true
            ),
            VocabularyWord(
                id: 2,
                word: "easy",
                listNumber: 1,
                level: 4,
                nextReviewDate: tomorrow
            )
        ]

        let result = SpacedRepetition.sessionCandidates(
            from: words,
            selectedList: 0,
            onlyDifficult: true,
            on: referenceDate,
            calendar: calendar,
            shuffled: false
        )
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testMasteredFutureWordsCompleteSession() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let words = [
            VocabularyWord(id: 1, word: "done", listNumber: 1, level: 5, nextReviewDate: tomorrow)
        ]
        XCTAssertTrue(
            SpacedRepetition.sessionCandidates(
                from: words,
                selectedList: 0,
                onlyDifficult: false,
                on: referenceDate,
                calendar: calendar,
                shuffled: false
            ).isEmpty
        )
    }
}


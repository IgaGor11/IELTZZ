import XCTest
@testable import WordFlow500

final class AnswerMatcherTests: XCTestCase {
    private let word = VocabularyWord(
        id: 1,
        word: "so-called",
        listNumber: 5,
        translation: "так называемый"
    )

    func testTranslationMatchingIgnoresCaseAndOuterWhitespace() {
        XCTAssertTrue(AnswerMatcher.matches("  ТАК НАЗЫВАЕМЫЙ ", word: word, mode: .wordToTranslation))
    }

    func testTranslationMatchingAcceptsAnyBuiltInVariant() {
        let wordWithVariants = VocabularyWord(
            id: 401,
            word: "abandon",
            listNumber: 5,
            translation: "покидать, отказываться"
        )

        XCTAssertTrue(AnswerMatcher.matches("покидать", word: wordWithVariants, mode: .wordToTranslation))
        XCTAssertTrue(AnswerMatcher.matches("ОТКАЗЫВАТЬСЯ", word: wordWithVariants, mode: .wordToTranslation))
        XCTAssertFalse(AnswerMatcher.matches("оставлять", word: wordWithVariants, mode: .wordToTranslation))
    }

    func testTranslationMatchingDoesNotDiscardRussianDiacritics() {
        let word = VocabularyWord(
            id: 1,
            word: "mine",
            listNumber: 1,
            translation: "мой"
        )

        XCTAssertTrue(AnswerMatcher.matches("МОЙ", word: word, mode: .wordToTranslation))
        XCTAssertFalse(AnswerMatcher.matches("мои", word: word, mode: .wordToTranslation))
    }

    func testReverseMatchingIgnoresCase() {
        XCTAssertTrue(AnswerMatcher.matches("SO-CALLED", word: word, mode: .translationToWord))
    }

    func testSpellingRequiresExactCaseAndPunctuation() {
        XCTAssertTrue(AnswerMatcher.matches("so-called", word: word, mode: .spelling))
        XCTAssertFalse(AnswerMatcher.matches("SO-CALLED", word: word, mode: .spelling))
        XCTAssertFalse(AnswerMatcher.matches("socalled", word: word, mode: .spelling))
    }
}

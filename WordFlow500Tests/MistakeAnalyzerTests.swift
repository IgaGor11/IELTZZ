import XCTest
@testable import WordFlow500

final class MistakeAnalyzerTests: XCTestCase {
    func testDetectsNearMissAndUnrelatedAnswer() {
        XCTAssertTrue(
            MistakeAnalyzer.message(
                submittedAnswer: "достегать",
                expectedAnswer: "достигать",
                mode: .wordToTranslation
            ).contains("близок")
        )
        XCTAssertTrue(
            MistakeAnalyzer.message(
                submittedAnswer: "машина",
                expectedAnswer: "достигать",
                mode: .wordToTranslation
            ).contains("Сравните")
        )
    }

    func testExplainsStrictSpellingAndManualAssessment() {
        XCTAssertTrue(
            MistakeAnalyzer.message(
                submittedAnswer: "Achieve",
                expectedAnswer: "achieve",
                mode: .spelling
            ).contains("точный регистр")
        )
        XCTAssertTrue(
            MistakeAnalyzer.message(
                submittedAnswer: nil,
                expectedAnswer: "achieve",
                mode: .spelling
            ).contains("дополнительного повторения")
        )
    }
}

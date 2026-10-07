import XCTest
@testable import WordFlow500

final class SeedWordsTests: XCTestCase {
    func testContainsExactlyFiveListsOfOneHundredWords() {
        XCTAssertEqual(SeedWords.lists.count, 5)
        XCTAssertEqual(SeedWords.lists.map(\.count), [100, 100, 100, 100, 100])
        XCTAssertEqual(SeedWords.all.count, 500)
    }

    func testStableIDsAndBoundaryWords() {
        XCTAssertEqual(SeedWords.all.map(\.id), Array(1...500))
        XCTAssertEqual(SeedWords.all.first?.word, "achieve")
        XCTAssertEqual(SeedWords.all.last?.word, "whereby")
        XCTAssertEqual(SeedWords.all.filter { $0.word == "global" }.count, 2)
    }

    func testEveryWordHasABuiltInRussianTranslation() {
        XCTAssertEqual(SeedWords.translations.count, 500)
        XCTAssertEqual(Set(SeedWords.translations.keys), Set(1...500))
        XCTAssertTrue(
            SeedWords.all.allSatisfy {
                !SeedWords.translation(for: $0.id)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            }
        )
    }

    func testEveryWordHasThreeBuiltInUsageExamples() {
        XCTAssertEqual(SeedExamples.byID.count, 500)
        XCTAssertEqual(Set(SeedExamples.byID.keys), Set(1...500))
        XCTAssertTrue(
            SeedWords.all.allSatisfy { seed in
                let examples = SeedExamples.examples(for: seed.id)
                return examples.count == 3
                    && Set(examples).count == 3
                    && examples.allSatisfy {
                        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && $0.localizedCaseInsensitiveContains(seed.word)
                    }
            }
        )
    }
}

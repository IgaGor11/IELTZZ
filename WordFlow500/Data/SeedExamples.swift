enum SeedExamples {
    static let byID: [Int: [String]] = {
        SeedExamplesPart1.byID
            .merging(SeedExamplesPart2.byID) { _, newer in newer }
            .merging(SeedExamplesPart3.byID) { _, newer in newer }
    }()

    static func examples(for id: Int) -> [String] {
        byID[id] ?? []
    }
}

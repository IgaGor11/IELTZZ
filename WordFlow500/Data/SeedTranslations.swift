extension SeedWords {
    static let translations: [Int: String] = {
        SeedTranslationsPart1.translations
            .merging(SeedTranslationsPart2.byID) { _, newer in newer }
            .merging(translationsPart3) { _, newer in newer }
    }()

    static func translation(for id: Int) -> String {
        translations[id] ?? ""
    }
}

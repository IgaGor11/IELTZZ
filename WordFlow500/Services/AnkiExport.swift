import Foundation

/// Выгрузка списка для Anki/Quizlet: TSV «слово \t перевод \t пример».
/// Всё бесплатно и офлайн, без нейросети.
enum AnkiExport {
    static func tsv(for words: [VocabularyWord]) -> String {
        words.map { word in
            [
                word.word,
                word.trimmedTranslation,
                word.example.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
            .map { $0.replacingOccurrences(of: "\t", with: " ") }
            .joined(separator: "\t")
        }
        .joined(separator: "\n")
    }

    static func fileName(listName: String) -> String {
        let safe = listName
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .prefix(40)
        return "ielts-\(safe).tsv"
    }
}

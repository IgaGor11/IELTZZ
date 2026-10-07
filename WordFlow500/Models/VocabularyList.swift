import Foundation

struct VocabularyList: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    var name: String
    let isBuiltIn: Bool
    let createdAt: Date

    init(
        id: Int,
        name: String,
        isBuiltIn: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    static let builtIn: [VocabularyList] = (1...5).map {
        VocabularyList(
            id: $0,
            name: "Список \($0)",
            isBuiltIn: true,
            createdAt: .distantPast
        )
    }
}

struct BatchImportResult: Equatable, Sendable {
    let addedCount: Int
    let skippedEntries: [String]
}

enum VocabularyStoreError: LocalizedError, Equatable {
    case emptyListName
    case duplicateListName
    case missingList
    case emptyWord
    case duplicateWord(String)
    case builtInListDeletion
    case builtInWordDeletion

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Введите название списка."
        case .duplicateListName:
            "Список с таким названием уже существует."
        case .missingList:
            "Выбранный список больше не существует."
        case .emptyWord:
            "Введите английское слово."
        case .duplicateWord(let word):
            "Слово «\(word)» уже есть в приложении."
        case .builtInListDeletion:
            "Встроенные списки можно переименовывать, но нельзя удалять."
        case .builtInWordDeletion:
            "Встроенные слова нельзя удалять."
        }
    }
}

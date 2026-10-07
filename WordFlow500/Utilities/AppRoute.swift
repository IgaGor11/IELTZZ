import Foundation

enum AppRoute: Hashable {
    case wordEditor(id: Int)
}

enum SheetDestination: Identifiable {
    case settings
    case drawing(wordID: Int)

    var id: String {
        switch self {
        case .settings:
            "settings"
        case .drawing(let wordID):
            "drawing-\(wordID)"
        }
    }
}

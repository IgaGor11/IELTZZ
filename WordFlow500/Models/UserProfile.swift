import Foundation

struct UserProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

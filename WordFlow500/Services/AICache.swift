import Foundation
import Combine

final class AICache: ObservableObject {
    private var storage: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        storage[key]
    }

    func set(_ data: Data, for key: String) {
        storage[key] = data
    }

    func clear() {
        storage.removeAll()
    }
}
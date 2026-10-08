import Foundation

struct AttemptRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let attemptedAt: Date
    let latency: TimeInterval
    let correct: Bool
    let mode: StudyMode

    init(
        id: UUID = UUID(),
        attemptedAt: Date = Date(),
        latency: TimeInterval = 0,
        correct: Bool,
        mode: StudyMode
    ) {
        self.id = id
        self.attemptedAt = attemptedAt
        self.latency = latency
        self.correct = correct
        self.mode = mode
    }
}

import Foundation

struct MistakeRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let submittedAnswer: String?
    let expectedAnswer: String
    let mode: StudyMode
    let practicedAt: Date
    let analysis: String?
    var correctedAt: Date?

    init(
        id: UUID = UUID(),
        submittedAnswer: String?,
        expectedAnswer: String,
        mode: StudyMode,
        practicedAt: Date,
        analysis: String? = nil,
        correctedAt: Date? = nil
    ) {
        self.id = id
        self.submittedAnswer = submittedAnswer
        self.expectedAnswer = expectedAnswer
        self.mode = mode
        self.practicedAt = practicedAt
        self.analysis = analysis
        self.correctedAt = correctedAt
    }
}

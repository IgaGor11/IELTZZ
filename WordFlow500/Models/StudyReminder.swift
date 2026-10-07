import Foundation

struct StudyReminder: Identifiable, Codable, Hashable, Sendable {
    static let validWeekdays = Set(1...7)

    var id: UUID
    var title: String
    var enabled: Bool
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>
    var listID: Int?
    var onlyDifficult: Bool
    var targetCount: Int

    init(
        id: UUID = UUID(),
        title: String = "Вечернее повторение",
        enabled: Bool = false,
        hour: Int = 19,
        minute: Int = 0,
        weekdays: Set<Int> = StudyReminder.validWeekdays,
        listID: Int? = nil,
        onlyDifficult: Bool = false,
        targetCount: Int = 20
    ) {
        self.id = id
        self.title = title
        self.enabled = enabled
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.listID = listID
        self.onlyDifficult = onlyDifficult
        self.targetCount = targetCount
    }

    var effectiveListID: Int? {
        guard let listID, listID > 0 else { return nil }
        return listID
    }

    func normalized() -> StudyReminder {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.hour = min(max(hour, 0), 23)
        copy.minute = min(max(minute, 0), 59)
        copy.weekdays = weekdays.intersection(Self.validWeekdays)
        copy.targetCount = min(max(targetCount, 1), 5_000)
        if let listID, listID < 0 {
            copy.listID = nil
        }
        return copy
    }
}

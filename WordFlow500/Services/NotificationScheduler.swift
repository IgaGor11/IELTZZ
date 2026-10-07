import Foundation
import UserNotifications

struct StudyReminderRequestDescriptor: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
    let userInfo: [String: String]
}

struct StudyReminderReconciliationPlan: Equatable, Sendable {
    let desiredIdentifiers: Set<String>
    let staleIdentifiers: [String]
    let projectedPendingRequestCount: Int
    let maximumPendingRequestCount: Int
}

enum StudyReminderRequestPlanner {
    static let systemMaximumPendingRequestCount = 64

    static func makePlan(
        profileID: String,
        pendingIdentifiers: [String],
        desiredIdentifiers: [String],
        maximumPendingRequestCount: Int
    ) throws -> StudyReminderReconciliationPlan {
        let maximum = max(maximumPendingRequestCount, 1)
        let prefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: profileID) + "."
        let pending = Set(pendingIdentifiers)
        let profilePending = Set(
            pending.filter { $0.hasPrefix(prefix) }
        )
        let desired = Set(desiredIdentifiers)
        let additional = desired.subtracting(pending)
        let projectedCount = pending.count + additional.count
        let replaceableDesiredCount = desired.intersection(pending).count
        let freeRequestCount = max(maximum - pending.count, 0)
        let availableDesiredCount =
            replaceableDesiredCount + freeRequestCount

        guard projectedCount <= maximum else {
            throw NotificationSchedulerError.requestLimitExceeded(
                requested: desired.count,
                available: availableDesiredCount,
                maximum: maximum
            )
        }

        return StudyReminderReconciliationPlan(
            desiredIdentifiers: desired,
            staleIdentifiers: profilePending
                .subtracting(desired)
                .sorted(),
            projectedPendingRequestCount: projectedCount,
            maximumPendingRequestCount: maximum
        )
    }
}

enum StudyReminderRequestBuilder {
    private static let identifierRoot = "com.wordflow500.study-reminder"

    static func makeDescriptors(
        profileID: String,
        reminders: [StudyReminder]
    ) -> [StudyReminderRequestDescriptor] {
        reminders.flatMap { reminder -> [StudyReminderRequestDescriptor] in
            let normalized = reminder.normalized()
            guard normalized.enabled else { return [] }

            return normalized.weekdays.sorted().map { weekday in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = normalized.hour
                components.minute = normalized.minute

                return StudyReminderRequestDescriptor(
                    identifier: [
                        identifierPrefix(forProfileID: profileID),
                        normalized.id.uuidString.lowercased(),
                        "weekday",
                        String(weekday)
                    ].joined(separator: "."),
                    title: normalized.title.isEmpty
                        ? "Время повторить слова"
                        : normalized.title,
                    body: notificationBody(for: normalized),
                    dateComponents: components,
                    userInfo: [
                        "profileID": profileID,
                        "reminderID": normalized.id.uuidString,
                        "listID": String(normalized.effectiveListID ?? 0),
                        "onlyDifficult": String(normalized.onlyDifficult),
                        "targetCount": String(normalized.targetCount)
                    ]
                )
            }
        }
    }

    static func identifierPrefix(forProfileID profileID: String) -> String {
        "\(identifierRoot).profile.\(profileToken(for: profileID))"
    }

    static func profileToken(for profileID: String) -> String {
        let base64 = Data(profileID.utf8).base64EncodedString()
        let token = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return token.isEmpty ? "_" : token
    }

    private static func notificationBody(
        for reminder: StudyReminder
    ) -> String {
        let scope: String
        if let listID = reminder.effectiveListID {
            scope = "из списка \(listID)"
        } else {
            scope = "из всех списков"
        }

        let count = reminder.targetCount
        var result = "Повторите \(count) \(wordForm(for: count)) \(scope)."
        if reminder.onlyDifficult {
            result += " Только слова, отмеченные как сложные."
        }
        return result
    }

    private static func wordForm(for count: Int) -> String {
        let remainder100 = count % 100
        if 11...14 ~= remainder100 {
            return "слов"
        }

        switch count % 10 {
        case 1:
            return "слово"
        case 2...4:
            return "слова"
        default:
            return "слов"
        }
    }
}

enum StudyNotificationAuthorizationStatus: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var permitsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        }
    }

    var title: String {
        switch self {
        case .notDetermined:
            "Разрешение ещё не запрошено"
        case .denied:
            "Уведомления запрещены"
        case .authorized:
            "Уведомления разрешены"
        case .provisional:
            "Уведомления доставляются тихо"
        case .ephemeral:
            "Временное разрешение"
        }
    }

    var systemImage: String {
        switch self {
        case .notDetermined:
            "bell.badge"
        case .denied:
            "bell.slash.fill"
        case .authorized:
            "bell.fill"
        case .provisional, .ephemeral:
            "bell.badge.fill"
        }
    }

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .notDetermined
        }
    }
}

enum NotificationSchedulerError: LocalizedError {
    case authorizationRequired
    case authorizationDenied
    case requestLimitExceeded(
        requested: Int,
        available: Int,
        maximum: Int
    )
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            "Включите напоминание, чтобы запросить разрешение на уведомления."
        case .authorizationDenied:
            "Уведомления запрещены в настройках iOS."
        case .requestLimitExceeded(
            let requested,
            let available,
            let maximum
        ):
            """
            Расписание создаёт \(requested) уведомлений, но сейчас доступно \(available) из системного лимита \(maximum). Уменьшите число выбранных дней или отключите другие напоминания.
            """
        case .schedulingFailed(let message):
            "Не удалось обновить расписание: \(message)"
        }
    }
}

@MainActor
final class NotificationScheduler {
    private let center: UNUserNotificationCenter
    private let maximumPendingRequestCount: Int

    init(
        center: UNUserNotificationCenter = .current(),
        maximumPendingRequestCount: Int =
            StudyReminderRequestPlanner.systemMaximumPendingRequestCount
    ) {
        self.center = center
        self.maximumPendingRequestCount = max(
            maximumPendingRequestCount,
            1
        )
    }

    func authorizationStatus() async -> StudyNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        return StudyNotificationAuthorizationStatus(settings.authorizationStatus)
    }

    func requestAuthorizationForEnabling() async throws -> Bool {
        let status = await authorizationStatus()
        if status.permitsScheduling {
            return true
        }
        if status == .denied {
            return false
        }

        let granted = try await center.requestAuthorization(
            options: [.alert, .sound]
        )
        guard granted else { return false }
        return await authorizationStatus().permitsScheduling
    }

    @discardableResult
    func synchronize(
        reminders: [StudyReminder],
        profileID: String
    ) async throws -> Int {
        let prefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: profileID) + "."
        let pending = await center.pendingNotificationRequests()
        let oldProfileRequests = pending.filter {
            $0.identifier.hasPrefix(prefix)
        }

        let descriptors = StudyReminderRequestBuilder.makeDescriptors(
            profileID: profileID,
            reminders: reminders
        )
        guard !descriptors.isEmpty else {
            center.removePendingNotificationRequests(
                withIdentifiers: oldProfileRequests.map(\.identifier)
            )
            return 0
        }

        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            throw NotificationSchedulerError.authorizationRequired
        case .denied:
            throw NotificationSchedulerError.authorizationDenied
        }

        let desiredRequests = descriptors.map(makeNotificationRequest)
        let plan = try StudyReminderRequestPlanner.makePlan(
            profileID: profileID,
            pendingIdentifiers: pending.map(\.identifier),
            desiredIdentifiers: desiredRequests.map(\.identifier),
            maximumPendingRequestCount: maximumPendingRequestCount
        )

        do {
            for request in desiredRequests {
                try await center.add(request)
            }
        } catch {
            center.removePendingNotificationRequests(
                withIdentifiers: Array(plan.desiredIdentifiers)
            )
            let recoveryWarning = await restore(oldProfileRequests)
            let details = [error.localizedDescription, recoveryWarning]
                .compactMap { $0 }
                .joined(separator: " ")
            throw NotificationSchedulerError.schedulingFailed(
                details
            )
        }

        center.removePendingNotificationRequests(
            withIdentifiers: plan.staleIdentifiers
        )
        return plan.desiredIdentifiers.count
    }

    func removeAllRequests(profileID: String) async {
        let prefix = StudyReminderRequestBuilder
            .identifierPrefix(forProfileID: profileID) + "."
        let pending = await center.pendingNotificationRequests()
        let profileRequestIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(
            withIdentifiers: profileRequestIDs
        )
    }

    private func makeNotificationRequest(
        descriptor: StudyReminderRequestDescriptor
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = descriptor.title
        content.body = descriptor.body
        content.sound = .default
        content.threadIdentifier = StudyReminderRequestBuilder
            .identifierPrefix(
                forProfileID: descriptor.userInfo["profileID"] ?? ""
            )
        content.userInfo = descriptor.userInfo

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: descriptor.dateComponents,
            repeats: true
        )
        return UNNotificationRequest(
            identifier: descriptor.identifier,
            content: content,
            trigger: trigger
        )
    }

    private func restore(
        _ requests: [UNNotificationRequest]
    ) async -> String? {
        var errors: [String] = []
        for request in requests {
            do {
                try await center.add(request)
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        guard !errors.isEmpty else { return nil }
        return "Не удалось полностью восстановить прежнее расписание: "
            + errors.joined(separator: "; ")
    }
}

import Foundation
import UserNotifications

struct StudyNotificationPayload: Equatable, Sendable {
    let profileID: UUID
    let listID: Int?
    let onlyDifficult: Bool
    let targetCount: Int

    init(
        profileID: UUID,
        listID: Int?,
        onlyDifficult: Bool,
        targetCount: Int
    ) {
        self.profileID = profileID
        self.listID = listID.flatMap { $0 > 0 ? $0 : nil }
        self.onlyDifficult = onlyDifficult
        self.targetCount = min(max(targetCount, 1), 5_000)
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard
            let profileValue = Self.stringValue(
                userInfo["profileID"]
            ),
            let profileID = UUID(uuidString: profileValue)
        else {
            return nil
        }

        self.init(
            profileID: profileID,
            listID: Self.integerValue(userInfo["listID"]),
            onlyDifficult: Self.boolValue(
                userInfo["onlyDifficult"]
            ) ?? false,
            targetCount: Self.integerValue(
                userInfo["targetCount"]
            ) ?? 20
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            value
        case let value as UUID:
            value.uuidString
        default:
            nil
        }
    }

    private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            value
        case let value as NSNumber:
            value.intValue
        case let value as String:
            Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            value
        case let value as NSNumber:
            value.boolValue
        case let value as String:
            switch value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            {
            case "true", "1", "yes":
                true
            case "false", "0", "no":
                false
            default:
                nil
            }
        default:
            nil
        }
    }
}

final class NotificationResponseHandler:
    NSObject,
    UNUserNotificationCenterDelegate
{
    var onResponse: ((StudyNotificationPayload) -> Void)?

    func install(on center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let payload = StudyNotificationPayload(
            userInfo: response.notification.request.content.userInfo
        )
        if let payload {
            DispatchQueue.main.async { [weak self] in
                self?.onResponse?(payload)
            }
        }
        completionHandler()
    }
}

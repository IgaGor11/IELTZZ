import XCTest
@testable import WordFlow500

final class NotificationResponseHandlerTests: XCTestCase {
    func testPayloadParsesSchedulerUserInfo() throws {
        let profileID = UUID()

        let payload = try XCTUnwrap(
            StudyNotificationPayload(
                userInfo: [
                    "profileID": profileID.uuidString,
                    "listID": "4",
                    "onlyDifficult": "true",
                    "targetCount": "17"
                ]
            )
        )

        XCTAssertEqual(payload.profileID, profileID)
        XCTAssertEqual(payload.listID, 4)
        XCTAssertTrue(payload.onlyDifficult)
        XCTAssertEqual(payload.targetCount, 17)
    }

    func testPayloadNormalizesNumericValuesAndRejectsMissingProfile() {
        let profileID = UUID()
        let payload = StudyNotificationPayload(
            userInfo: [
                "profileID": profileID,
                "listID": NSNumber(value: 0),
                "onlyDifficult": NSNumber(value: false),
                "targetCount": NSNumber(value: 10_000)
            ]
        )

        XCTAssertEqual(payload?.profileID, profileID)
        XCTAssertNil(payload?.listID)
        XCTAssertEqual(payload?.onlyDifficult, false)
        XCTAssertEqual(payload?.targetCount, 5_000)
        XCTAssertNil(
            StudyNotificationPayload(
                userInfo: [
                    "listID": "2",
                    "onlyDifficult": "true",
                    "targetCount": "10"
                ]
            )
        )
    }
}

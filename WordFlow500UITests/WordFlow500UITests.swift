import XCTest

final class WordFlow500UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingReset",
            "-settings.autoplayPronunciation",
            "NO"
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testStudyFeedbackWaitsForButtonAndStatisticsLivesInTab() {
        XCTAssertTrue(
            app.navigationBars["500 Words"].waitForExistence(timeout: 8)
        )
        XCTAssertFalse(app.staticTexts["Всего"].exists)

        let knowButton = app.buttons["knowButton"]
        XCTAssertTrue(knowButton.waitForExistence(timeout: 3))
        knowButton.tap()

        let continueButton = app.buttons["continueButton"]
        let examples = app.descendants(matching: .any)["usageExamples"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertTrue(examples.waitForExistence(timeout: 3))

        let firstCardAnswer = app.staticTexts["Правильный ответ"]
        XCTAssertTrue(firstCardAnswer.exists)
        sleep(2)
        XCTAssertTrue(
            continueButton.exists,
            "Карточка не должна переключаться автоматически"
        )
        XCTAssertTrue(firstCardAnswer.exists)

        continueButton.tap()
        XCTAssertTrue(app.buttons["knowButton"].waitForExistence(timeout: 3))

        let disclosure = app.descendants(matching: .any)[
            "cardExtrasDisclosure"
        ]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 3))
        disclosure.tap()
        XCTAssertTrue(
            app.staticTexts["Ваш пример"].waitForExistence(timeout: 3)
        )

        app.tabBars.buttons["Статистика"].tap()
        XCTAssertTrue(
            app.navigationBars["Статистика"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["Статистика обучения"]
                .waitForExistence(timeout: 3)
        )
    }

    func testBothListPickersAndVocabularyManagementStayStable() {
        XCTAssertTrue(
            app.navigationBars["500 Words"].waitForExistence(timeout: 8)
        )

        let settingsBar = app.navigationBars["Настройки"]
        XCTAssertTrue(
            openToolbarDestination(
                identifier: "settingsButton",
                horizontalOffset: 0.93,
                destination: settingsBar
            )
        )
        choose(
            pickerIdentifier: "settingsListPicker",
            option: "Список 2"
        )
        XCTAssertTrue(app.navigationBars["Настройки"].exists)
        app.buttons["Готово"].tap()

        app.tabBars.buttons["Слова"].tap()
        XCTAssertTrue(
            app.navigationBars["Слова"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["wordRow-101"].waitForExistence(timeout: 3))

        choose(
            pickerIdentifier: "wordListPicker",
            option: "Список 3"
        )
        XCTAssertTrue(app.navigationBars["Слова"].exists)
        XCTAssertTrue(app.buttons["wordRow-201"].waitForExistence(timeout: 3))

        app.buttons["vocabularyActionsButton"].tap()
        app.buttons["Добавить пачкой"].tap()
        XCTAssertTrue(
            app.navigationBars["Пакетный импорт"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["batchWordsEditor"].exists
        )
        app.buttons["Закрыть"].tap()

        app.buttons["vocabularyActionsButton"].tap()
        app.buttons["Управление списками"].tap()
        XCTAssertTrue(
            app.navigationBars["Управление списками"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["addListButton"].exists)
    }

    func testProfileAndReminderSettingsOpen() {
        XCTAssertTrue(
            app.navigationBars["500 Words"].waitForExistence(timeout: 8)
        )
        let settingsBar = app.navigationBars["Настройки"]
        XCTAssertTrue(
            openToolbarDestination(
                identifier: "settingsButton",
                horizontalOffset: 0.93,
                destination: settingsBar
            )
        )

        let profiles = app.descendants(matching: .any)[
            "profilesSettingsLink"
        ]
        reveal(profiles)
        XCTAssertTrue(profiles.exists)
        profiles.tap()
        XCTAssertTrue(
            app.navigationBars["Профили"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["addProfileButton"].exists)
        app.navigationBars["Профили"].buttons.firstMatch.tap()

        let reminders = app.descendants(matching: .any)[
            "remindersSettingsLink"
        ]
        reveal(reminders)
        XCTAssertTrue(reminders.exists)
        reminders.tap()
        XCTAssertTrue(
            app.navigationBars["Напоминания"].waitForExistence(timeout: 3)
        )
        app.buttons["addReminderButton"].tap()
        XCTAssertTrue(
            app.navigationBars["Новое напоминание"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.switches["Включено"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["reminderTimePicker"]
                .waitForExistence(timeout: 3)
        )
        app.buttons["Отмена"].tap()
    }

    private func choose(
        pickerIdentifier: String,
        option: String
    ) {
        let picker = app.descendants(matching: .any)[pickerIdentifier]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "Не найден Picker \(pickerIdentifier)"
        )
        picker.tap()

        let button = app.buttons[option]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }

        let text = app.staticTexts[option]
        XCTAssertTrue(text.waitForExistence(timeout: 2))
        text.tap()
    }

    private func openToolbarDestination(
        identifier: String,
        horizontalOffset: CGFloat,
        destination: XCUIElement
    ) -> Bool {
        let button = app.buttons[identifier]
        guard button.waitForExistence(timeout: 3) else { return false }

        for attempt in 0..<3 {
            if attempt == 0, button.isHittable {
                button.tap()
            } else {
                app.navigationBars["500 Words"]
                    .coordinate(
                        withNormalizedOffset: CGVector(
                            dx: horizontalOffset,
                            dy: 0.55
                        )
                    )
                    .tap()
            }
            if destination.waitForExistence(timeout: 2) {
                return true
            }
        }
        return false
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<4 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
    }
}

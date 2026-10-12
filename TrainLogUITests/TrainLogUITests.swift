import XCTest

final class TrainLogUITests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-ui-testing"]; app.launch()
        let skip = app.buttons["skipOnboarding"]
        if skip.waitForExistence(timeout: 10) { skip.tap() }
        return app
    }
    @MainActor func testQuickChestRecordAppearsInHistoryAndCanBeDeleted() {
        let app = launch()
        app.tabBars.buttons["训练"].tap()
        app.buttons["quickWorkout"].tap()
        XCTAssertTrue(app.navigationBars["快速记录"].waitForExistence(timeout: 10))
        let chest = app.buttons["muscle.chest"]
        // Materialize the lazy grid, then let XCTest scroll the specific button
        // into view. Full-screen swipes can overshoot it on a slower runner.
        for _ in 0..<6 {
            if chest.waitForExistence(timeout: 1) { break }
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(chest.exists)
        chest.tap()
        XCTAssertTrue(chest.isSelected)
        let selection = XCTAttachment(screenshot: app.screenshot())
        selection.name = "Quick record - chest selected (test data)"
        selection.lifetime = .keepAlways
        add(selection)
        app.buttons["finishWorkout"].tap()
        let done = app.buttons["closeSummary"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        if !done.isHittable { app.swipeUp() }; done.tap()
        app.buttons["openFitnessCalendar"].tap()
        app.buttons["calendar.today"].tap()
        for _ in 0..<3 {
            if app.staticTexts["胸部训练"].exists { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(app.staticTexts["胸部训练"].waitForExistence(timeout: 5))
        let calendarShot = XCTAttachment(screenshot: app.screenshot())
        calendarShot.name = "Native fitness calendar - completed workout (test data)"
        calendarShot.lifetime = .keepAlways
        add(calendarShot)
        app.buttons["calendar.close"].tap()
        let history = app.buttons["训练历史"]
        if !history.isHittable { app.swipeUp() }; history.tap()
        XCTAssertTrue(app.staticTexts["胸部训练"].waitForExistence(timeout: 5))
        app.staticTexts["胸部训练"].tap()
        for _ in 0..<4 where !app.buttons["删除训练"].isHittable { app.swipeUp() }
        app.buttons["删除训练"].tap()
        app.sheets.buttons["删除训练"].tap()
        XCTAssertTrue(app.staticTexts["暂无对应训练"].waitForExistence(timeout: 5))
    }
    @MainActor func testDraftCanBeResumedWithoutCountingAsCompleted() {
        let app = launch()
        app.buttons["startWorkout"].tap()
        app.buttons["稍后继续"].tap()
        XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["startWorkout"].label.contains("继续"))
        app.buttons["startWorkout"].tap()
        XCTAssertTrue(app.buttons["addExercise"].exists)
    }
    @MainActor func testEmptyTabsDoNotCrash() {
        let app = launch()
        for label in ["趋势", "能力", "训练", "概览"] { app.tabBars.buttons[label].tap(); XCTAssertTrue(app.navigationBars.firstMatch.exists) }
    }
    @MainActor func testCalendarAvailableFromEveryTabAndPreservesSelectedDate() {
        let app = launch()
        for label in ["概览", "训练", "趋势", "能力"] {
            app.tabBars.buttons[label].tap()
            app.buttons["openFitnessCalendar"].tap()
            XCTAssertTrue(app.navigationBars["健身日历"].waitForExistence(timeout: 5))
            app.buttons["calendar.close"].tap()
        }
        app.buttons["openFitnessCalendar"].tap()
        app.buttons["calendar.today"].tap()
        let day = app.staticTexts["calendar.selectedDay"]
        for _ in 0..<3 {
            if app.buttons["calendar.nextDay"].isHittable { break }
            app.swipeUp(velocity: .slow)
        }
        let today = day.label
        app.buttons["calendar.nextDay"].tap()
        XCTAssertNotEqual(day.label, today)
        let tomorrow = day.label
        app.buttons["calendar.close"].tap()
        app.buttons["openFitnessCalendar"].tap()
        for _ in 0..<3 {
            if day.exists { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertEqual(day.label, tomorrow)
        app.buttons["calendar.today"].tap()
        XCTAssertEqual(day.label, today)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native fitness calendar - date navigation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}


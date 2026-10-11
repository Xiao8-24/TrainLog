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
}


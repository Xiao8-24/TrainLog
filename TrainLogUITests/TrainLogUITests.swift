import XCTest
import UIKit

final class TrainLogUITests: XCTestCase {
    @MainActor private func launch(extraArguments: [String] = [], persistent: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-ui-testing"] + extraArguments
        if persistent { app.launchEnvironment["TRAINLOG_UI_TEST_STORE"] = UUID().uuidString }
        app.launch()
        let skip = app.buttons["skipOnboarding"]
        if skip.waitForExistence(timeout: 10) { skip.tap() }
        return app
    }
    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func openDeepLink(_ url: URL) async {
        let opened = await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(opened, "The system must accept the registered TrainLog URL")
    }
    @MainActor func testWidgetDeepLinksDismissModalAndResumePersistedDraft() async {
        let app = launch(persistent: true)
        app.buttons["设置"].tap()
        await openDeepLink(URL(string: "trainlog://calendar")!)
        let calendarOpened = app.navigationBars["健身日历"].waitForExistence(timeout: 10)
        capture(app, name: "Widget calendar deep link after launch")
        XCTAssertTrue(calendarOpened)
        guard calendarOpened else { return }
        // Open a workout while the same shared calendar used by all tabs is up.
        await openDeepLink(URL(string: "trainlog://workout")!)
        XCTAssertTrue(app.buttons["startRestTimer"].waitForExistence(timeout: 10))
        app.buttons["稍后继续"].tap()
        app.terminate(); app.launch()
        let resume = app.buttons["startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        XCTAssertTrue(resume.label.contains("继续"))
        await openDeepLink(URL(string: "trainlog://workout")!)
        XCTAssertTrue(app.buttons["startRestTimer"].waitForExistence(timeout: 10))
        capture(app, name: "Widget deep link resumes the training draft")
    }
    @MainActor func testNativeAppearanceAndFloatingRestControls() {
        let app = launch()
        for appearance in ["浅色", "深色"] {
            app.buttons["设置"].tap()
            let picker = app.descendants(matching: .any)["settings.appearance"].firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap()
            app.buttons[appearance].tap()
            app.navigationBars.buttons["完成"].tap()
            XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 5))
            capture(app, name: "Native overview - \(appearance)")
            app.buttons["startWorkout"].tap()
            app.buttons["startRestTimer"].tap()
            let interactionStarted = Date()
            app.buttons["180 秒"].tap()
            XCTAssertLessThan(Date().timeIntervalSince(interactionStarted), 15, "Starting rest must not wait for the notification service")
            let end = app.buttons["restTimer.end"]
            XCTAssertTrue(end.waitForExistence(timeout: 5))
            XCTAssertTrue(end.isHittable)
            XCTAssertTrue(app.staticTexts["restTimer.remaining"].exists)
            capture(app, name: "Native floating rest controls - \(appearance)")
            end.tap()
            XCTAssertTrue(end.waitForNonExistence(timeout: 5))
            app.buttons["稍后继续"].tap()
        }
    }
    @MainActor func testRestControlsAtAccessibilityTextSize() {
        let app = launch(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["startWorkout"].tap()
        let timer = app.buttons["startRestTimer"]
        for _ in 0..<4 where !timer.isHittable { app.swipeUp(velocity: .slow) }
        timer.tap(); app.buttons["180 秒"].tap()
        let end = app.buttons["restTimer.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(end.isHittable)
        // Inspect the actual controls without introducing an accessibility
        // container around a glass surface that updates every second.
        for control in [app.staticTexts["restTimer.label"], app.staticTexts["restTimer.remaining"], end] {
            XCTAssertTrue(control.exists)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        capture(app, name: "Native floating rest controls - accessibility text")
        end.tap()
        XCTAssertTrue(end.waitForNonExistence(timeout: 5))
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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native fitness calendar - date navigation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        for _ in 0..<3 {
            if day.exists { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertEqual(day.label, today)
    }
}


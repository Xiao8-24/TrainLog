import XCTest

final class TrainLogUITests: XCTestCase {
    @MainActor func testPlanReviewAndEditableActualCopy() {
        let app = launch(extraArguments: ["-ui-review-targets"])
        app.tabBars.buttons["训练"].tap()
        let history = app.buttons["训练历史"]
        for _ in 0..<8 where !history.isHittable { app.swipeUp(velocity: .slow) }
        history.tap()
        let record = app.descendants(matching: .any)["history.session.81000000-0000-0000-0000-000000000002"].firstMatch
        for _ in 0..<8 where !record.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(record.exists); record.tap()
        let details = app.buttons["review.details"]
        for _ in 0..<10 where !details.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(details.exists); details.tap()
        XCTAssertTrue(app.navigationBars["计划与实际"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未计时完成组"].exists)
        capture(app, name: "Plan versus actual comparison - isolated UI test data")
        app.navigationBars.buttons.firstMatch.tap()
        let copy = app.buttons["review.copyActual"]
        for _ in 0..<6 where !copy.isHittable { app.swipeUp(velocity: .slow) }
        copy.tap(); XCTAssertTrue(app.navigationBars["编辑计划"].waitForExistence(timeout: 5))
        let changed = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "plan.itemSummary.", "60 kg × 9 次")).firstMatch
        let unchanged = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "plan.itemSummary.", "60 kg × 8 次")).firstMatch
        XCTAssertTrue(changed.exists); XCTAssertTrue(unchanged.exists)
        capture(app, name: "Actual copy preserves varied targets before saving - UI test data")
        app.buttons["plan.save"].tap()
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
    }
    @MainActor func testTargetSuggestionCancelAcceptAndDisable() {
        let app = launch(extraArguments: ["-ui-review-targets"])
        app.tabBars.buttons["训练"].tap()
        let plans = app.buttons["trainingPlans"]
        for _ in 0..<8 where !plans.isHittable { app.swipeUp(velocity: .slow) }
        plans.tap()
        let next = app.descendants(matching: .any)["plan.row.81000000-0000-0000-0000-000000000003"].firstMatch
        for _ in 0..<8 where !next.isHittable { app.swipeUp(velocity: .slow) }
        next.tap(); app.buttons["plan.edit"].tap(); app.buttons["plan.configure"].tap()
        let suggestion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "targetSuggestion.")).firstMatch
        for _ in 0..<6 where !suggestion.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(suggestion.exists); suggestion.tap()
        XCTAssertEqual(app.staticTexts["suggestion.title"].label, "可尝试多一次")
        XCTAssertEqual(app.textFields["suggestion.reps"].value as? String, "9")
        capture(app, name: "Explainable target suggestion with source records - UI test data")
        app.navigationBars.buttons["取消"].tap()
        let reps = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "target.reps.")).firstMatch
        XCTAssertEqual(reps.value as? String, "8", "Cancel must not adopt a suggestion")
        suggestion.tap(); app.buttons["suggestion.apply"].tap()
        XCTAssertEqual(reps.value as? String, "9")
        app.navigationBars.buttons["保存"].tap(); app.buttons["plan.save"].tap()
        app.tabBars.buttons["概览"].tap(); app.buttons["设置"].tap()
        let toggle = app.switches["settings.targetSuggestions"]
        XCTAssertTrue(toggle.exists); toggle.tap(); app.navigationBars.buttons["完成"].tap()
        app.tabBars.buttons["训练"].tap(); app.buttons["plan.edit"].tap(); app.buttons["plan.configure"].tap()
        XCTAssertEqual(reps.value as? String, "9")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "targetSuggestion.")).count, 0)
        capture(app, name: "Accepted item retained while suggestions disabled - UI test data")
    }
    @MainActor func testSetDetailsAndFloatingControlsPreserveInput() {
        checkSetControls(extraArguments: [], screenshotSuffix: "standard motion")
    }
    @MainActor func testSetControlsWithReducedMotionAndAccessibilityText() {
        checkSetControls(extraArguments: ["-ui-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], screenshotSuffix: "reduced motion and accessibility text")
    }
    @MainActor private func checkSetControls(extraArguments: [String], screenshotSuffix: String) {
        let app = launch(extraArguments: extraArguments)
        app.tabBars.buttons["训练"].tap()
        let template = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "template.start.", "Push · 胸肩三头")).firstMatch
        for _ in 0..<10 where !template.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(template.exists); template.tap()
        XCTAssertTrue(app.navigationBars["正在训练"].waitForExistence(timeout: 8))
        let weight = app.textFields["setWeight.1"].firstMatch
        for _ in 0..<10 where !weight.isHittable { app.swipeUp(velocity: .slow) }
        weight.tap(); weight.typeText("60")
        let reps = app.textFields["setReps.1"].firstMatch
        for _ in 0..<5 where !reps.isHittable { app.swipeUp(velocity: .slow) }
        reps.tap(); reps.typeText("8"); app.buttons["收起键盘"].tap()
        let options = app.buttons["set.options.1"].firstMatch
        for _ in 0..<10 where !options.isHittable { app.swipeUp(velocity: .slow) }
        options.tap()
        XCTAssertEqual(options.value as? String, "已展开")
        let notes = app.textFields["set.notes.1"].firstMatch
        for _ in 0..<8 where !notes.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(notes.exists); notes.tap(); notes.typeText("keep this set note")
        app.buttons["收起键盘"].tap()
        for _ in 0..<10 where !options.isHittable { app.swipeDown(velocity: .slow) }
        options.tap(); XCTAssertEqual(options.value as? String, "已折叠")
        options.tap()
        for _ in 0..<8 where !notes.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertEqual(notes.value as? String, "keep this set note")
        for _ in 0..<10 where !options.isHittable { app.swipeDown(velocity: .slow) }
        options.tap()
        let begin = app.buttons["set.start.1"].firstMatch
        for _ in 0..<8 where !begin.isHittable { app.swipeDown(velocity: .slow) }
        begin.tap()
        let finish = app.buttons["activeSet.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        let pause = app.buttons["workout.toggleTimer"]
        for _ in 0..<12 where !pause.isHittable { app.swipeDown(velocity: .slow) }
        pause.tap()
        XCTAssertTrue(app.staticTexts["activeSet.status"].label.contains("已暂停"))
        XCTAssertTrue(finish.isHittable)
        capture(app, name: "Paused floating set - " + screenshotSuffix + " - UI test data")
        pause.tap()
        XCTAssertTrue(app.staticTexts["activeSet.status"].label.contains("进行中"))
        finish.tap()
        let end = app.buttons["restTimer.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5)); XCTAssertTrue(end.isHittable)
        for control in [app.staticTexts["restTimer.label"], app.staticTexts["restTimer.remaining"], end] {
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        capture(app, name: "Set to rest surface - " + screenshotSuffix + " - UI test data")
        end.tap(); XCTAssertTrue(end.waitForNonExistence(timeout: 5))
        for _ in 0..<10 where !weight.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertEqual(weight.value as? String, "60")
        XCTAssertTrue(app.buttons["completeSet.1"].firstMatch.label.contains("已完成"))
        capture(app, name: "Completed set preserves input - " + screenshotSuffix + " - UI test data")
    }
    @MainActor func testCreatePlanThenStartAndRecordTimedSet() {
        let app = launch()
        app.tabBars.buttons["训练"].tap()
        let plans = app.buttons["trainingPlans"]
        for _ in 0..<5 where !plans.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(plans.exists); plans.tap(); app.buttons["plan.new"].tap()
        let menu = app.descendants(matching: .any)["plan.template"].firstMatch
        menu.tap()
        let option = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Push · 胸肩三头")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
        app.buttons["plan.save"].tap()
        let plan = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.row.")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5)); plan.tap()
        capture(app, name: "Dated training plan before starting - UI test data")
        let start = app.buttons["plan.start"]
        for _ in 0..<6 where !start.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(start.exists); start.tap()
        XCTAssertTrue(app.navigationBars["正在训练"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["workout.elapsed"].exists)
        let begin = app.buttons["set.start.1"].firstMatch
        for _ in 0..<6 where !begin.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(begin.exists); begin.tap()
        XCTAssertTrue(app.buttons["activeSet.finish"].waitForExistence(timeout: 5))
        let weight = app.textFields["setWeight.1"].firstMatch
        weight.tap(); weight.typeText("60")
        let reps = app.textFields["setReps.1"].firstMatch
        reps.tap(); reps.typeText("8"); app.buttons["收起键盘"].tap()
        capture(app, name: "Live set timer and overall timer - UI test data")
        app.buttons["activeSet.finish"].tap()
        XCTAssertTrue(app.buttons["restTimer.end"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["completeSet.1"].firstMatch.label.contains("已完成"))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.navigationBars["训练完成"].waitForExistence(timeout: 8))
    }
    @MainActor func testRunningSetSurvivesBackgroundAndPausedSetSurvivesRelaunch() {
        let app = launch(persistent: true)
        app.tabBars.buttons["训练"].tap()
        let template = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "template.start.", "Push · 胸肩三头")).firstMatch
        for _ in 0..<8 where !template.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(template.exists); template.tap()
        XCTAssertTrue(app.navigationBars["正在训练"].waitForExistence(timeout: 8))
        let begin = app.buttons["set.start.1"].firstMatch
        for _ in 0..<6 where !begin.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(begin.exists); begin.tap()
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["activeSet.finish"].waitForExistence(timeout: 10))
        let pause = app.buttons["workout.toggleTimer"]
        for _ in 0..<8 where !pause.isHittable { app.swipeDown(velocity: .slow) }
        XCTAssertTrue(pause.exists); pause.tap()
        app.buttons["稍后继续"].tap(); app.terminate(); app.launch()
        let resume = app.buttons["startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10)); resume.tap()
        XCTAssertTrue(app.buttons["activeSet.finish"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["workout.toggleTimer"].label, "继续计时")
        capture(app, name: "Paused set restored after relaunch - UI test data")
    }
    @MainActor func testLinkedPhoneWorkoutShowsOneRecordAndWatchSummary() {
        let app = launch(extraArguments: ["-ui-linked-watch"])
        app.tabBars.buttons["训练"].tap()
        let history = app.buttons["训练历史"]
        for _ in 0..<5 where !history.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(history.exists); history.tap()
        let row = app.staticTexts["界面测试力量训练"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let attached = app.staticTexts["手表结果已附加到这次训练"]
        for _ in 0..<8 where !attached.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(attached.waitForExistence(timeout: 5))
        capture(app, name: "Linked strength record - synthetic isolated UI test data")
        let average = app.descendants(matching: .any)["cardio.averageHeartRate"].firstMatch
        for _ in 0..<5 where !average.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(average.exists)
        XCTAssertEqual(average.value as? String, "120 次/分")
        capture(app, name: "Linked Watch heart chart - synthetic isolated UI test data")
    }
    @MainActor func testShortcutHomeAndStaleLinksDoNotCreateReplacementWorkouts() {
        let app = launch()
        openDeepLink(URL(string: "trainlog://training")!)
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["cardioWorkout"].exists)
        openDeepLink(URL(string: "trainlog://workout/\(UUID().uuidString)")!)
        XCTAssertTrue(app.buttons["cardioWorkout"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finishWorkout"].exists)
        openDeepLink(URL(string: "trainlog://template/\(UUID().uuidString)")!)
        let alert = app.alerts["未能完成操作"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5)); alert.buttons["好"].tap()
        XCTAssertTrue(app.buttons["cardioWorkout"].exists)
    }
    @MainActor func testDraftLastEditSurvivesBackgroundAndRelaunch() {
        let app = launch(persistent: true)
        app.tabBars.buttons["训练"].tap(); app.buttons["quickWorkout"].tap()
        XCTAssertTrue(app.navigationBars["快速记录"].waitForExistence(timeout: 10))
        let note = app.textFields["workout.notes"]
        let multilineNote = app.textViews["workout.notes"]
        for _ in 0..<8 where !note.isHittable && !multilineNote.isHittable { app.swipeUp(velocity: .slow) }
        let field = note.exists ? note : multilineNote
        XCTAssertTrue(field.exists); field.tap(); field.typeText("latest note 062")
        // Background immediately, without an explicit save/close action.
        XCUIDevice.shared.press(.home)
        app.terminate(); app.launch()
        let resume = app.buttons["startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10)); resume.tap()
        XCTAssertTrue(app.navigationBars["快速记录"].waitForExistence(timeout: 10))
        for _ in 0..<8 where !note.isHittable && !multilineNote.isHittable { app.swipeUp(velocity: .slow) }
        let restored = note.exists ? note : multilineNote
        XCTAssertEqual(restored.value as? String, "latest note 062")
        capture(app, name: "Draft restored after background and cold relaunch")
    }
    @MainActor func testCardioRecordingSummaryAndCalendar() {
        let app = launch()
        app.tabBars.buttons["训练"].tap()
        let start = app.buttons["cardioWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
        XCTAssertTrue(app.navigationBars["运动记录"].waitForExistence(timeout: 5))
        let distance = app.textFields["cardio.distance"]
        for _ in 0..<4 where !distance.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(distance.exists); distance.tap(); distance.typeText("5")
        let minutes = app.textFields["workout.manualMinutes"]
        app.buttons["收起键盘"].tap()
        for _ in 0..<4 where !minutes.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(minutes.exists); minutes.tap(); minutes.typeText("30")
        app.buttons["收起键盘"].tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.navigationBars["训练完成"].waitForExistence(timeout: 8))
        capture(app, name: "Cardio summary - manual run with honest missing sensor data")
        let done = app.buttons["closeSummary"]
        for _ in 0..<8 where !done.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(done.exists); done.tap()
        app.buttons["openFitnessCalendar"].tap(); app.buttons["calendar.today"].tap()
        let run = app.staticTexts["户外跑步"].firstMatch
        for _ in 0..<5 where !run.exists { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        capture(app, name: "Cardio record in native fitness calendar")
    }
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
    @MainActor private func openDeepLink(_ url: URL) {
        // Use the UI automation system proxy. An ordinary UIApplication request
        // from the background test runner is correctly rejected as untrusted.
        XCUIDevice.shared.system.open(url)
    }
    @MainActor func testWidgetDeepLinksDismissModalAndResumePersistedDraft() {
        let app = launch(persistent: true)
        app.buttons["设置"].tap()
        openDeepLink(URL(string: "trainlog://calendar")!)
        let calendarOpened = app.navigationBars["健身日历"].waitForExistence(timeout: 10)
        capture(app, name: "Widget calendar deep link after launch")
        XCTAssertTrue(calendarOpened)
        guard calendarOpened else { return }
        // Open a workout while the same shared calendar used by all tabs is up.
        openDeepLink(URL(string: "trainlog://workout")!)
        XCTAssertTrue(app.buttons["startRestTimer"].waitForExistence(timeout: 10))
        app.buttons["稍后继续"].tap()
        app.terminate(); app.launch()
        let resume = app.buttons["startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        XCTAssertTrue(resume.label.contains("继续"))
        openDeepLink(URL(string: "trainlog://workout")!)
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
            openDeepLink(URL(string: "trainlog://rest/\(UUID().uuidString)/end")!)
            XCTAssertTrue(end.waitForExistence(timeout: 5), "A stale shortcut must not end another workout's rest")
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
    @MainActor func testAppleHealthConnectionIsOptionalAndUnavailableInIsolatedTests() {
        let app = launch()
        app.buttons["设置"].tap()
        let health = app.buttons["settings.appleHealth"]
        for _ in 0..<4 where !health.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(health.waitForExistence(timeout: 5)); health.tap()
        XCTAssertTrue(app.navigationBars["Apple 健康"].waitForExistence(timeout: 5))
        let toggle = app.switches["health.enabled"]
        XCTAssertTrue(toggle.exists); XCTAssertFalse(toggle.isEnabled)
        let authorization = app.descendants(matching: .any)["health.authorization"].firstMatch
        XCTAssertTrue(authorization.exists)
        XCTAssertEqual(authorization.value as? String, "当前不可用")
        capture(app, name: "Apple Health optional connection - isolated environment")
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


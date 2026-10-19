import XCTest
import TrainLogCore
@testable import TrainLog

@MainActor final class DraftSaveTests: XCTestCase {
    func testRapidEditsCoalesceToLatestDraft() async {
        let original = Session(mode: .quick)
        let saves = expectation(description: "Only latest edit saved")
        saves.assertForOverFulfill = true
        let controller = DraftSaveController(saved: original, delay: .zero)
        var saved: [Session] = []
        let write: (Session) throws -> Void = { saved.append($0); saves.fulfill() }
        var value = original; value.notes = "第一版"; controller.schedule(value, save: write)
        value.notes = "最终内容"; controller.schedule(value, save: write)
        await fulfillment(of: [saves], timeout: 5)
        XCTAssertEqual(saved.map(\.notes), ["最终内容"])
        controller.stop()
    }
    func testFlushCancelsQueuedWritesAndUnchangedCloseDoesNotSaveAgain() async throws {
        let original = Session(mode: .quick)
        let controller = DraftSaveController(saved: original, delay: .zero)
        var saved: [Session] = []
        var value = original; value.notes = "立即离开前的最后输入"
        controller.schedule(value) { saved.append($0) }
        try controller.flush(value) { saved.append($0) }
        try controller.flush(value) { saved.append($0) }
        await Task.yield()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.notes, value.notes)
        controller.stop()
    }
    func testFailedWriteCanRetrySameDraftWithoutLosingContent() throws {
        let original = Session(mode: .quick)
        let controller = DraftSaveController(saved: original)
        var value = original; value.notes = "保存失败后保留"
        XCTAssertThrowsError(try controller.flush(value) { _ in throw ValidationError("磁盘暂不可用") })
        guard case .failed = controller.state else { return XCTFail("Must report unsaved data") }
        var saved: Session?
        try controller.flush(value) { saved = $0 }
        XCTAssertEqual(saved?.notes, value.notes)
        guard case .saved = controller.state else { return XCTFail("Retry must report durable save") }
    }
    func testInvalidNumericDraftDoesNotOverwriteStoredVersion() async throws {
        let original = Session(mode: .quick)
        let controller = DraftSaveController(saved: original, delay: .zero)
        var invalid = original; invalid.sessionRPE = .nan
        var writes = 0
        controller.schedule(invalid) { _ in writes += 1 }
        controller.schedule(invalid) { _ in writes += 1 }
        await Task.yield()
        XCTAssertEqual(writes, 0)
        guard case .failed = controller.state else { return XCTFail("Invalid input must stay unsaved") }
        invalid.sessionRPE = 8
        try controller.flush(invalid) { _ in writes += 1 }
        XCTAssertEqual(writes, 1)
    }
    func testFinishingOrDiscardingStopsOldDraftResurrection() async {
        let original = Session(mode: .quick)
        let controller = DraftSaveController(saved: original, delay: .zero)
        var value = original; value.notes = "排队中的旧草稿"
        var writes = 0
        controller.schedule(value) { _ in writes += 1 }
        controller.stop()
        controller.schedule(value) { _ in writes += 1 }
        await Task.yield()
        XCTAssertEqual(writes, 0)
    }
}

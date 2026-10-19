import XCTest
@testable import TrainLogCore

final class TrainingIntentRouteTests: XCTestCase {
    func testApprovedShortcutRoutesRoundTripAndRejectAmbiguousCommands() {
        let id = UUID()
        for route in [WorkoutDeepLink.training, .template(id), .endRest(id)] {
            XCTAssertEqual(WorkoutDeepLink(url: route.url), route)
        }
        for value in ["trainlog://template", "trainlog://template/invalid", "trainlog://rest/\(id)/start", "trainlog://rest/\(id)", "trainlog://rest/\(id)/end?all=true", "trainlog://training/extra"] {
            XCTAssertNil(WorkoutDeepLink(url: URL(string: value)!))
        }
    }
    func testOldWidgetSnapshotDecodesWithoutShortcutMetadataAndExpiredRestIsNotPublished() throws {
        let now = Date()
        let draft = Session(mode: .detailed, date: now)
        let snapshot = WorkoutWidgetSnapshot(sessions: [draft], weeklyGoal: 4, now: now, restDeadline: now.addingTimeInterval(-1))
        XCTAssertNil(snapshot.restDeadline)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        json.removeValue(forKey: "templates"); json.removeValue(forKey: "restDeadline")
        let decoded = try JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.templates); XCTAssertNil(decoded.restDeadline); XCTAssertEqual(decoded.draftID, draft.id)
        let live = WorkoutWidgetSnapshot(sessions: [draft], weeklyGoal: 4, now: now, restDeadline: now.addingTimeInterval(60))
        XCTAssertNotNil(live.restDeadline)
        XCTAssertNil(WorkoutWidgetSnapshot(sessions: [], weeklyGoal: 4, now: now, restDeadline: now.addingTimeInterval(60)).restDeadline)
    }
}

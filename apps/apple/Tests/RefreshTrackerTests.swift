import XCTest
@testable import FreyaPlayerCore

final class RefreshTrackerTests: XCTestCase {
    @MainActor
    func testTracksDynamicRequestProgressAndPreventsConcurrentRefreshes() throws {
        let tracker = RefreshTracker()
        let refreshID = try XCTUnwrap(tracker.beginRefresh())

        XCTAssertNil(tracker.beginRefresh())
        XCTAssertEqual(tracker.progress, RefreshProgress(completed: 0, total: 0))

        XCTAssertTrue(tracker.registerRequest(for: refreshID))
        XCTAssertTrue(tracker.registerRequest(for: refreshID))
        tracker.completeRequest(for: refreshID)

        XCTAssertEqual(tracker.progress, RefreshProgress(completed: 1, total: 2))

        tracker.finishRefresh(refreshID)

        XCTAssertNil(tracker.progress)
        XCTAssertNotNil(tracker.beginRefresh())
    }

    @MainActor
    func testCancelClearsProgressAndIgnoresLateCompletions() throws {
        let tracker = RefreshTracker()
        let refreshID = try XCTUnwrap(tracker.beginRefresh())
        XCTAssertTrue(tracker.registerRequest(for: refreshID))

        tracker.cancelAll()
        tracker.completeRequest(for: refreshID)

        XCTAssertNil(tracker.progress)
        XCTAssertFalse(tracker.registerRequest(for: refreshID))
        XCTAssertNotNil(tracker.beginRefresh())
    }
}

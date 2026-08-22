import XCTest
@testable import FreyaPlayerCore

final class RefreshTrackerTests: XCTestCase {
    @MainActor
    func testTracksLibraryRefreshStateAndPreventsConcurrentRefreshes() throws {
        let tracker = RefreshTracker()
        let refreshID = try XCTUnwrap(tracker.beginRefresh())

        XCTAssertNil(tracker.beginRefresh())
        XCTAssertTrue(tracker.isLibraryRefreshInProgress)

        tracker.finishRefresh(refreshID)

        XCTAssertFalse(tracker.isLibraryRefreshInProgress)
        XCTAssertNotNil(tracker.beginRefresh())
    }

    @MainActor
    func testCancelClearsStateAndPreventsRestartUntilRefreshFinishes() throws {
        let tracker = RefreshTracker()
        let refreshID = try XCTUnwrap(tracker.beginRefresh())

        tracker.cancelAll()

        XCTAssertFalse(tracker.isLibraryRefreshInProgress)
        XCTAssertNil(tracker.beginRefresh())

        tracker.finishRefresh(refreshID)

        XCTAssertNotNil(tracker.beginRefresh())
    }
}

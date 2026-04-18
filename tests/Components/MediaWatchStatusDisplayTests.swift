import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaWatchStatusDisplayTests: XCTestCase {
    func testTitlesReflectWatchProgress() {
        XCTAssertEqual(MediaWatchStatusDisplay.title(progress: nil, isWatched: false), "Unwatched")
        XCTAssertEqual(MediaWatchStatusDisplay.title(progress: 0.245, isWatched: false), "25%")
        XCTAssertEqual(MediaWatchStatusDisplay.title(progress: 0.2, isWatched: true), "Watched")
    }
}

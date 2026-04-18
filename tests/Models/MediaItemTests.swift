import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaItemTests: XCTestCase {
    func testFormattingAndResumeState() {
        let item = makeMediaItem(
            title: "Movie",
            durationMilliseconds: 5_400_000,
            progress: 0.4,
            resumeOffsetMilliseconds: 12_000
        )

        XCTAssertEqual(item.runtimeText, "1h 30m")
        XCTAssertEqual(item.subtitle, "2024 • 1h 30m")
        XCTAssertTrue(item.hasResume)
        XCTAssertEqual(item.playbackID?.itemID, item.id)
        XCTAssertEqual(item.artworkURL, item.artwork.posterURL)
        XCTAssertEqual(item.backdropURL, item.artwork.backdropURL)
        XCTAssertEqual(MediaItemKind.episode.artworkStyle, .landscape)
        XCTAssertFalse(MediaItemKind.season.isPlayable)
    }

    func testSettingWatchStatusClearsResumeState() {
        let item = makeMediaItem(progress: 0.5, resumeOffsetMilliseconds: 2_000)
        let watched = item.settingWatchStatus(true)
        let unwatched = item.settingWatchStatus(false)

        XCTAssertTrue(watched.isWatched)
        XCTAssertEqual(watched.progress, 1)
        XCTAssertNil(watched.resumeOffsetMilliseconds)
        XCTAssertFalse(unwatched.isWatched)
        XCTAssertNil(unwatched.progress)
    }
}

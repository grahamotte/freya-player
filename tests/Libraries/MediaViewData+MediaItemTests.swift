import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaViewDataMediaItemTests: XCTestCase {
    func testMapsMetadata() {
        let item = makeMediaItem(contentRating: "TV-14", resumeOffsetMilliseconds: 30_000)
        let data = item.mediaViewData()

        XCTAssertEqual(data.title, item.title)
        XCTAssertEqual(data.metadata.map(\.label), ["Year", "Length", "Rating"])
        XCTAssertEqual(data.metadata.map(\.value), ["2024", "2h", "TV-14"])
        XCTAssertEqual(data.playbackID, item.playbackID)
        XCTAssertTrue(data.hasResume)
        XCTAssertEqual(data.resumeOffsetMilliseconds, 30_000)
    }
}

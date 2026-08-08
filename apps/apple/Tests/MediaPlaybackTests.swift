import XCTest
@testable import FreyaPlayerCore

final class MediaPlaybackTests: XCTestCase {
    func testQualityMetadata() {
        XCTAssertEqual(MediaPlaybackQuality.automatic.title, "Automatic")
        XCTAssertNil(MediaPlaybackQuality.automatic.maxStreamingBitrate)
        XCTAssertEqual(MediaPlaybackQuality.p1080.maxVideoBitrate, 20_000)
        XCTAssertEqual(MediaPlaybackQuality.p720.videoResolution, "720")
        XCTAssertEqual(MediaPlaybackQuality.p240.maxStreamingBitrate, 700_000)
    }
}

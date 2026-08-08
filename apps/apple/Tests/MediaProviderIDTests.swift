import XCTest
@testable import FreyaPlayerCore

final class MediaProviderIDTests: XCTestCase {
    func testTitles() {
        XCTAssertEqual(MediaProviderID.plex.title, "Plex")
        XCTAssertEqual(MediaProviderID.jellyfin.title, "Jellyfin")
    }
}

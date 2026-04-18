import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlatformMetadataTests: XCTestCase {
    func testMatchesTarget() {
        #if os(tvOS)
        XCTAssertEqual(PlatformMetadata.plexPlatformName, "tvOS")
        XCTAssertEqual(PlatformMetadata.deviceName, "Apple TV")
        #else
        XCTAssertEqual(PlatformMetadata.plexPlatformName, "iOS")
        XCTAssertEqual(PlatformMetadata.deviceName, "iPad")
        #endif
    }
}

import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class AppRouteTests: XCTestCase {
    func testRoutesMapLibrariesItemsAndProviderSettings() {
        let library = makeLibraryReference(providerID: .plex)
        let episode = makeMediaItem(providerID: .plex, kind: .episode)

        XCTAssertEqual(library.route, .library(library))
        XCTAssertEqual(episode.route, .episode(episode))
        XCTAssertEqual(MediaProviderID.jellyfin.settingsRoute, .jellyfinSettings)
    }
}

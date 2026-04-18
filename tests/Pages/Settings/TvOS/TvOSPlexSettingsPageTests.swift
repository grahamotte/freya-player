#if os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class TvOSPlexSettingsPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(PlexSettingsPage(model: context.model, path: context.path))
    }
}

#endif

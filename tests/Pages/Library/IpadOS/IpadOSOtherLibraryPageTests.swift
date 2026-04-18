#if !os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class IpadOSOtherLibraryPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(OtherLibraryPage(model: context.model, library: context.otherLibrary, path: context.path))
    }
}

#endif

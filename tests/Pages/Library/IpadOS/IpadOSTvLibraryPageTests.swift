#if !os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class IpadOSTvLibraryPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(TvLibraryPage(model: context.model, library: context.showLibrary, path: context.path))
    }
}

#endif

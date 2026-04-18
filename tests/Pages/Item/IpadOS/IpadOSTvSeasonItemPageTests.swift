#if !os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class IpadOSTvSeasonItemPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(TvSeasonItemPage(model: context.model, item: context.season))
    }
}

#endif

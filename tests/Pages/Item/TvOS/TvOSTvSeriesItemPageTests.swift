#if os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class TvOSTvSeriesItemPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(TvSeriesItemPage(model: context.model, item: context.series))
    }
}

#endif

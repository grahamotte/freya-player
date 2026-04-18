import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class AppViewTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(AppView(model: context.model))
    }
}

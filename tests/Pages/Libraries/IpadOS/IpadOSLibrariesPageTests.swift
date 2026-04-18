#if !os(tvOS)
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class IpadOSLibrariesPageTests: XCTestCase {
    func testRenders() {
        let context = makeViewTestContext(testCase: self)
        assertRenders(LibrariesPage(model: context.model, server: context.server, path: context.path))
    }
}

#endif

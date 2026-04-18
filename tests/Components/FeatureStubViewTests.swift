import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class FeatureStubViewTests: XCTestCase {
    func testRenders() {
        assertRenders(FeatureStubView(title: "Stub", message: "Message"))
    }
}

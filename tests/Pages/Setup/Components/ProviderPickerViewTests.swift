import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class ProviderPickerViewTests: XCTestCase {
    func testRenders() {
        assertRenders(ProviderPickerView())
    }
}

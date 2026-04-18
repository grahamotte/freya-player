import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaLibraryTests: XCTestCase {
    func testSettingHiddenReturnsUpdatedShelf() {
        let shelf = makeLibraryShelf(isHidden: false)
        let updated = shelf.settingHidden(true)

        XCTAssertEqual(updated.id, shelf.id)
        XCTAssertTrue(updated.isHidden)
    }
}

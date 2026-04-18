import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class ConnectedServerTests: XCTestCase {
    func testSettingLibrariesReplacesOnlyLibraries() {
        let original = makeConnectedServer()
        let replacement = makeLibraryShelf(id: "second", title: "Second")
        let updated = original.settingLibraries([replacement])

        XCTAssertEqual(updated.serverID, original.serverID)
        XCTAssertEqual(updated.libraries, [replacement])
    }
}

import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class JellyfinSessionStoreTests: XCTestCase {
    func testTracksSavedConnection() async {
        let defaults = makeDefaults(testCase: self)
        let secureStore = TestSecureStore()
        let store = JellyfinSessionStore(
            defaults: defaults,
            loadSecureValue: secureStore.value(for:),
            saveSecureValue: secureStore.setValue(_:for:),
            removeSecureValue: secureStore.removeValue(for:)
        )

        XCTAssertFalse(store.hasSavedConnection)

        store.serverURL = "https://example.com"
        store.userID = "user"
        store.userName = "Graham"
        store.accessToken = "token"

        XCTAssertTrue(store.hasSavedConnection)
        store.clear()
        XCTAssertFalse(store.hasSavedConnection)
        XCTAssertNil(store.userName)
    }
}

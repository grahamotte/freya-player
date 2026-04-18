import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlexSessionStoreTests: XCTestCase {
    func testRoundTripsAndClears() async {
        let defaults = makeDefaults(testCase: self)
        let secureStore = TestSecureStore()
        let store = PlexSessionStore(
            defaults: defaults,
            loadSecureValue: secureStore.value(for:),
            saveSecureValue: secureStore.setValue(_:for:),
            removeSecureValue: secureStore.removeValue(for:)
        )

        store.userToken = "token"
        store.serverIdentifier = "server"
        store.setLibraryFilterRawValue(1, forLibraryID: "movies", serverID: "server")
        store.setLibrarySortRawValue(2, forLibraryID: "movies", serverID: "server")
        store.setLibrarySortOrderRawValue(0, forLibraryID: "movies", serverID: "server")

        XCTAssertEqual(store.userToken, "token")
        XCTAssertEqual(store.serverIdentifier, "server")
        XCTAssertEqual(store.libraryFilterRawValue(forLibraryID: "movies", serverID: "server"), 1)
        XCTAssertEqual(store.librarySortRawValue(forLibraryID: "movies", serverID: "server"), 2)
        XCTAssertEqual(store.librarySortOrderRawValue(forLibraryID: "movies", serverID: "server"), 0)

        store.clear()
        XCTAssertNil(store.userToken)
        XCTAssertNil(store.serverIdentifier)
    }
}

import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaSessionStoreTests: XCTestCase {
    func testRoundTripsFilterAndSortState() async {
        let defaults = makeDefaults(testCase: self)
        let store = MediaSessionStore(defaults: defaults)
        let library = makeLibraryReference(providerID: .plex, serverID: "server-1", id: "movies")

        store.setLibraryFilterRawValue(LibraryPageFilter.unwatched.rawValue, for: library)
        store.setLibrarySortRawValue(LibraryPageSort.addedAt.rawValue, for: library)
        store.setLibrarySortOrderRawValue(LibraryPageSortOrder.descending.rawValue, for: library)

        XCTAssertEqual(store.libraryFilterRawValue(for: library), LibraryPageFilter.unwatched.rawValue)
        XCTAssertEqual(store.librarySortRawValue(for: library), LibraryPageSort.addedAt.rawValue)
        XCTAssertEqual(store.librarySortOrderRawValue(for: library), LibraryPageSortOrder.descending.rawValue)
    }

    func testRoundTripsAndClearsLibraryManagementState() async {
        let defaults = makeDefaults(testCase: self)
        let store = MediaSessionStore(defaults: defaults)

        store.setLibraryOrder(["b", "a"], providerID: .plex, serverID: "server-1")
        store.setHiddenLibraryIDs(["a"], providerID: .plex, serverID: "server-1")

        XCTAssertEqual(store.libraryOrder(providerID: .plex, serverID: "server-1"), ["b", "a"])
        XCTAssertEqual(store.hiddenLibraryIDs(providerID: .plex, serverID: "server-1"), ["a"])

        store.clearLibraryManagement(providerID: .plex, serverID: "server-1")
        XCTAssertTrue(store.libraryOrder(providerID: .plex, serverID: "server-1").isEmpty)
        XCTAssertTrue(store.hiddenLibraryIDs(providerID: .plex, serverID: "server-1").isEmpty)
    }
}

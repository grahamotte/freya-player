import XCTest
@testable import FreyaPlayerCore

final class MediaSessionStoreTests: XCTestCase {
    func testRoundTripsAndClearsLibraryPreferences() {
        let defaults = MemoryDefaultsStore()
        let store = MediaSessionStore(defaults: defaults)
        let library = makeLibraryReference()

        store.setLibraryFilterRawValue(1, for: library)
        store.setLibrarySortRawValue(2, for: library)
        store.setLibrarySortOrderRawValue(3, for: library)
        XCTAssertEqual(store.libraryFilterRawValue(for: library), 1)
        XCTAssertEqual(store.librarySortRawValue(for: library), 2)
        XCTAssertEqual(store.librarySortOrderRawValue(for: library), 3)

        store.clearLibraryFilterRawValue(for: library)
        store.clearLibrarySortRawValue(for: library)
        store.clearLibrarySortOrderRawValue(for: library)
        XCTAssertNil(store.libraryFilterRawValue(for: library))
        XCTAssertNil(store.librarySortRawValue(for: library))
        XCTAssertNil(store.librarySortOrderRawValue(for: library))
    }

    func testScopesServerPreferencesByProviderAndServer() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())
        store.setLibraryOrder(["b", "a"], providerID: .plex, serverID: "one")
        store.setHiddenLibraryIDs(["a"], providerID: .plex, serverID: "one")

        XCTAssertEqual(store.libraryOrder(providerID: .plex, serverID: "one"), ["b", "a"])
        XCTAssertEqual(store.hiddenLibraryIDs(providerID: .plex, serverID: "one"), ["a"])
        XCTAssertTrue(store.libraryOrder(providerID: .jellyfin, serverID: "one").isEmpty)
    }
}

private final class MemoryDefaultsStore: DefaultsStore {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    func stringArray(forKey defaultName: String) -> [String]? { values[defaultName] as? [String] }
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}

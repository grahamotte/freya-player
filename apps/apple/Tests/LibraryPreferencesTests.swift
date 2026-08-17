import XCTest
@testable import FreyaPlayerCore

final class LibraryPreferencesTests: XCTestCase {
    func testBuiltInDefaultsAreUnwatchedAndAddedAtDescending() {
        let store = MediaSessionStore(defaults: LibraryPreferencesMemoryDefaultsStore())
        let library = makeLibraryReference()

        let sort = store.librarySort(for: library)

        XCTAssertEqual(store.libraryFilter(for: library), .unwatched)
        XCTAssertEqual(sort, .addedAt)
        XCTAssertEqual(store.librarySortOrder(for: library, sort: sort), .descending)
        XCTAssertEqual(store.defaultLibraryFilter(providerID: .plex, serverID: "server"), .unwatched)
        XCTAssertEqual(store.defaultLibrarySort(providerID: .plex, serverID: "server"), .addedAt)
    }

    func testLibraryPreferencesOverrideServerDefaults() {
        let store = MediaSessionStore(defaults: LibraryPreferencesMemoryDefaultsStore())
        let library = makeLibraryReference()

        store.setDefaultLibraryFilter(.unwatched, providerID: .plex, serverID: "server")
        store.setDefaultLibrarySort(.addedAt, providerID: .plex, serverID: "server")
        store.setLibraryFilter(.all, for: library)
        store.setLibrarySort(.title, for: library)
        store.setLibrarySortOrder(.descending, for: library)

        XCTAssertEqual(store.libraryFilter(for: library), .all)
        XCTAssertEqual(store.librarySort(for: library), .title)
        XCTAssertEqual(store.librarySortOrder(for: library, sort: .title), .descending)
    }
}

private final class LibraryPreferencesMemoryDefaultsStore: DefaultsStore {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    func stringArray(forKey defaultName: String) -> [String]? { values[defaultName] as? [String] }
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}

import XCTest
@testable import FreyaPlayerCore

final class LibraryPreferencesTests: XCTestCase {
    func testBuiltInDefaultsAreUnwatchedAndAddedAtDescending() {
        let defaults = LibraryPreferencesMemoryDefaultsStore()
        defaults.set(LibraryPageFilter.all.rawValue, forKey: "media.server.library.filter.default.plex.server")
        defaults.set(LibraryPageSort.title.rawValue, forKey: "media.server.library.sort.default.plex.server")
        defaults.set(LibraryPageSortOrder.ascending.rawValue, forKey: "media.server.library.sort.order.default.plex.server")
        let store = MediaSessionStore(defaults: defaults)
        let library = makeLibraryReference()

        let sort = store.librarySort(for: library)

        XCTAssertEqual(store.libraryFilter(for: library), .unwatched)
        XCTAssertEqual(sort, .addedAt)
        XCTAssertEqual(store.librarySortOrder(for: library, sort: sort), .descending)
    }

    func testLibraryPreferencesOverrideBuiltInDefaults() {
        let store = MediaSessionStore(defaults: LibraryPreferencesMemoryDefaultsStore())
        let library = makeLibraryReference()

        store.setLibraryFilter(.all, for: library)
        store.setLibrarySort(.title, for: library)
        store.setLibrarySortOrder(.descending, for: library)

        XCTAssertEqual(store.libraryFilter(for: library), .all)
        XCTAssertEqual(store.librarySort(for: library), .title)
        XCTAssertEqual(store.librarySortOrder(for: library, sort: .title), .descending)
    }

    func testLibraryFilterUsesSeenTerminology() {
        XCTAssertEqual(LibraryPageFilter.unwatched.title, "Unseen")
        XCTAssertEqual(LibraryPageFilter.unwatched.emptyStateText(for: "Movie"), "No unseen Movies.")
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

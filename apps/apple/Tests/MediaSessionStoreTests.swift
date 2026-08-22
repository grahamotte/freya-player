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

    func testPersistsPlaybackSettingsPerServerAndMediaItem() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())
        let id = MediaPlaybackID(providerID: .plex, itemID: "movie-one")
        let settings = MediaPlaybackSettings(
            quality: .p720,
            audioID: "french",
            subtitleID: nil
        )

        store.setPlaybackSettings(settings, for: id, serverID: "server-one")

        XCTAssertEqual(store.playbackSettings(for: id, serverID: "server-one"), settings)
        XCTAssertNil(store.playbackSettings(for: id, serverID: "server-two"))
        XCTAssertNil(store.playbackSettings(
            for: MediaPlaybackID(providerID: .plex, itemID: "movie-two"),
            serverID: "server-one"
        ))
        XCTAssertNil(store.playbackSettings(
            for: MediaPlaybackID(providerID: .jellyfin, itemID: "movie-one"),
            serverID: "server-one"
        ))
    }

    func testLibraryRefreshIsDueWhenNoPreviousRefreshWasStarted() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())

        XCTAssertTrue(store.shouldStartLibraryRefresh(
            providerID: .plex,
            serverID: "server-one",
            at: Date(timeIntervalSince1970: 1_000)
        ))
    }

    func testLibraryRefreshIsDueFifteenMinutesAfterItStarted() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())
        let startedAt = Date(timeIntervalSince1970: 1_000)
        store.setLibraryRefreshStartedAt(startedAt, providerID: .plex, serverID: "server-one")

        XCTAssertFalse(store.shouldStartLibraryRefresh(
            providerID: .plex,
            serverID: "server-one",
            at: startedAt.addingTimeInterval((15 * 60) - 1)
        ))
        XCTAssertTrue(store.shouldStartLibraryRefresh(
            providerID: .plex,
            serverID: "server-one",
            at: startedAt.addingTimeInterval(15 * 60)
        ))
    }

    func testLibraryRefreshStartIsScopedByProviderAndServer() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())
        let startedAt = Date(timeIntervalSince1970: 1_000)
        store.setLibraryRefreshStartedAt(startedAt, providerID: .plex, serverID: "server-one")

        XCTAssertTrue(store.shouldStartLibraryRefresh(
            providerID: .plex,
            serverID: "server-two",
            at: startedAt
        ))
        XCTAssertTrue(store.shouldStartLibraryRefresh(
            providerID: .jellyfin,
            serverID: "server-one",
            at: startedAt
        ))
    }

    func testLibraryRefreshIsDueAfterTheClockMovesBackward() {
        let store = MediaSessionStore(defaults: MemoryDefaultsStore())
        let startedAt = Date(timeIntervalSince1970: 1_000)
        store.setLibraryRefreshStartedAt(startedAt, providerID: .plex, serverID: "server-one")

        XCTAssertTrue(store.shouldStartLibraryRefresh(
            providerID: .plex,
            serverID: "server-one",
            at: startedAt.addingTimeInterval(-1)
        ))
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

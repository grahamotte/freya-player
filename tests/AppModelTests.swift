import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class AppModelTests: XCTestCase {
    func testRestoreIfNeededPrefersPlexAndRunsOnce() async {
        let plex = FakePlexConnector()
        let jellyfin = FakeJellyfinConnector()
        let plexServer = makeConnectedServer(providerID: .plex, serverID: "plex")
        plex.restoreConnectionResult = .success(plexServer)
        jellyfin.restoreConnectionResult = .success(makeConnectedServer(providerID: .jellyfin, serverID: "jelly"))

        let model = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: plex,
            jellyfinConnector: jellyfin
        )

        await model.restoreIfNeeded()
        await model.restoreIfNeeded()

        XCTAssertEqual(model.connectionState, .connected(plexServer))
    }

    func testConnectJellyfinTransitionsToConnectedOrFailed() async {
        let jellyfin = FakeJellyfinConnector()
        let server = makeConnectedServer(providerID: .jellyfin)
        jellyfin.connectResult = .success(server)

        let success = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: FakePlexConnector(),
            jellyfinConnector: jellyfin
        )
        success.connectJellyfin(serverURL: "https://jf.local", username: "me", password: "pw")
        await waitUntil {
            success.connectedServer == server
        }

        let failureConnector = FakeJellyfinConnector()
        failureConnector.connectResult = .failure(TestError.example)
        let failure = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: FakePlexConnector(),
            jellyfinConnector: failureConnector
        )
        failure.connectJellyfin(serverURL: "https://jf.local", username: "me", password: "pw")
        await waitUntil {
            if case .failed = failure.connectionState {
                return true
            }
            return false
        }
    }

    func testStartPlexLoginPublishesCodeAndConnectsOnApproval() async {
        let plex = FakePlexConnector()
        let server = makeConnectedServer(providerID: .plex)
        plex.beginLoginResult = .success(PlexLoginSession(id: 1, code: "ABCD", expiresAt: Date().addingTimeInterval(60)))
        plex.completeLoginResults = [.success(server)]
        let model = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: plex,
            jellyfinConnector: FakeJellyfinConnector()
        )

        model.startPlexLogin()

        await waitUntil {
            model.connectedServer == server
        }
        XCTAssertNil(model.plexLinkCode)
    }

    func testRefreshConnectionWithoutExistingServerSetsFailure() async {
        let jellyfin = FakeJellyfinConnector()
        jellyfin.hasSavedConnection = true
        jellyfin.refreshConnectionResult = .failure(TestError.example)
        let model = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: FakePlexConnector(),
            jellyfinConnector: jellyfin
        )

        model.prepareJellyfinSetup()
        await waitUntil {
            if case .failed = model.connectionState {
                return true
            }
            return false
        }
    }

    func testMoveLibraryAndHideLibraryPersistState() async {
        let defaults = makeDefaults(testCase: self)
        let store = MediaSessionStore(defaults: defaults)
        let libraries = [
            makeLibraryShelf(id: "a", title: "A", reference: makeLibraryReference(id: "a")),
            makeLibraryShelf(id: "b", title: "B", reference: makeLibraryReference(id: "b"))
        ]
        let server = makeConnectedServer(providerID: .jellyfin, serverID: "server", libraries: libraries)
        let jellyfin = FakeJellyfinConnector()
        jellyfin.restoreConnectionResult = .success(server)
        let model = AppModel(mediaSessionStore: store, plexConnector: FakePlexConnector(), jellyfinConnector: jellyfin)

        await model.restoreIfNeeded()
        model.moveLibrary(at: 0, by: 1)
        model.setLibraryHidden(true, at: 0)

        XCTAssertEqual(model.connectedServer?.libraries.map(\.id), ["b", "a"])
        XCTAssertEqual(model.connectedServer?.libraries.first?.isHidden, true)
        XCTAssertEqual(store.libraryOrder(providerID: .jellyfin, serverID: "server"), ["b", "a"])
        XCTAssertEqual(store.hiddenLibraryIDs(providerID: .jellyfin, serverID: "server"), ["b"])
    }

    func testSetWatchStatusRecursesIntoChildrenAndSkipsMatchingItems() async throws {
        let episode1 = makeMediaItem(providerID: .jellyfin, id: "e1", kind: .episode)
        let episode2 = makeMediaItem(providerID: .jellyfin, id: "e2", kind: .episode, isWatched: true)
        let season = makeMediaItem(providerID: .jellyfin, id: "season", kind: .season)
        let show = makeMediaItem(providerID: .jellyfin, id: "show", kind: .series)

        let jellyfin = FakeJellyfinConnector()
        jellyfin.childrenByID["show"] = .success([season])
        jellyfin.childrenByID["season"] = .success([episode1, episode2])
        let model = AppModel(
            mediaSessionStore: MediaSessionStore(defaults: makeDefaults(testCase: self)),
            plexConnector: FakePlexConnector(),
            jellyfinConnector: jellyfin
        )

        try await model.setWatchStatus(for: show, isWatched: true)

        XCTAssertEqual(jellyfin.watchStatusCalls.map(\.0.itemID), ["e1"])
        XCTAssertEqual(jellyfin.watchStatusCalls.map(\.1), [true])
    }
}

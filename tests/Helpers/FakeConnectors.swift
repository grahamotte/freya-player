import Foundation

#if os(tvOS)
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#else
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#endif

final class FakePlexConnector: PlexConnecting {
    let providerID: MediaProviderID = .plex

    var hasSavedConnection = false
    var restoreConnectionResult: Result<ConnectedServer?, Error> = .success(nil)
    var refreshConnectionResult: Result<ConnectedServer, Error> = .failure(MediaConnectorError.unavailable)
    var beginLoginResult: Result<PlexLoginSession, Error> = .failure(TestError.example)
    var completeLoginResults: [Result<ConnectedServer?, Error>] = []
    var libraryItemsByID: [String: [MediaItem]] = [:]
    var itemsByID: [String: MediaItem] = [:]
    var childrenByID: [String: Result<[MediaItem], Error>] = [:]
    var playbackOptionsByItemID: [String: MediaPlaybackOptions?] = [:]
    var playbackURLsByItemID: [String: URL] = [:]

    private(set) var disconnectCalls = 0
    private(set) var timelineCalls: [(MediaPlaybackID, MediaPlaybackTimelineState, Int, Int?, String)] = []
    private(set) var completedPlaybackIDs: [MediaPlaybackID] = []
    private(set) var watchStatusCalls: [(MediaPlaybackID, Bool)] = []

    func restoreConnection() async throws -> ConnectedServer? {
        try restoreConnectionResult.get()
    }

    func refreshConnection() async throws -> ConnectedServer {
        try refreshConnectionResult.get()
    }

    func disconnect() {
        disconnectCalls += 1
    }

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        libraryItemsByID[library.id] ?? []
    }

    func loadItem(_ item: MediaItem) async throws -> MediaItem {
        itemsByID[item.id] ?? item
    }

    func loadChildren(for item: MediaItem) async throws -> [MediaItem] {
        try childrenByID[item.id, default: .success([])].get()
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        playbackOptionsByItemID[id.itemID] ?? nil
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection?) async throws -> URL {
        playbackURLsByItemID[id.itemID] ?? URL(string: "https://example.com/\(id.itemID).m3u8")!
    }

    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws {
        timelineCalls.append((id, state, time, duration, sessionID))
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async throws {
        completedPlaybackIDs.append(id)
    }

    func setWatchStatus(for id: MediaPlaybackID, isWatched: Bool) async throws {
        watchStatusCalls.append((id, isWatched))
    }

    func beginLogin() async throws -> PlexLoginSession {
        try beginLoginResult.get()
    }

    func completeLoginIfAuthorized(session: PlexLoginSession) async throws -> ConnectedServer? {
        if completeLoginResults.isEmpty {
            return nil
        }

        return try completeLoginResults.removeFirst().get()
    }
}

final class FakeJellyfinConnector: JellyfinConnecting {
    let providerID: MediaProviderID = .jellyfin

    var hasSavedConnection = false
    var restoreConnectionResult: Result<ConnectedServer?, Error> = .success(nil)
    var refreshConnectionResult: Result<ConnectedServer, Error> = .failure(MediaConnectorError.unavailable)
    var connectResult: Result<ConnectedServer, Error> = .failure(TestError.example)
    var libraryItemsByID: [String: [MediaItem]] = [:]
    var itemsByID: [String: MediaItem] = [:]
    var childrenByID: [String: Result<[MediaItem], Error>] = [:]
    var playbackOptionsByItemID: [String: MediaPlaybackOptions?] = [:]
    var playbackURLsByItemID: [String: URL] = [:]

    private(set) var disconnectCalls = 0
    private(set) var connectCalls: [(String, String, String)] = []
    private(set) var timelineCalls: [(MediaPlaybackID, MediaPlaybackTimelineState, Int, Int?, String)] = []
    private(set) var completedPlaybackIDs: [MediaPlaybackID] = []
    private(set) var watchStatusCalls: [(MediaPlaybackID, Bool)] = []

    func restoreConnection() async throws -> ConnectedServer? {
        try restoreConnectionResult.get()
    }

    func refreshConnection() async throws -> ConnectedServer {
        try refreshConnectionResult.get()
    }

    func disconnect() {
        disconnectCalls += 1
    }

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        libraryItemsByID[library.id] ?? []
    }

    func loadItem(_ item: MediaItem) async throws -> MediaItem {
        itemsByID[item.id] ?? item
    }

    func loadChildren(for item: MediaItem) async throws -> [MediaItem] {
        try childrenByID[item.id, default: .success([])].get()
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        playbackOptionsByItemID[id.itemID] ?? nil
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection?) async throws -> URL {
        playbackURLsByItemID[id.itemID] ?? URL(string: "https://example.com/\(id.itemID).m3u8")!
    }

    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws {
        timelineCalls.append((id, state, time, duration, sessionID))
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async throws {
        completedPlaybackIDs.append(id)
    }

    func setWatchStatus(for id: MediaPlaybackID, isWatched: Bool) async throws {
        watchStatusCalls.append((id, isWatched))
    }

    func connect(serverURL: String, username: String, password: String) async throws -> ConnectedServer {
        connectCalls.append((serverURL, username, password))
        return try connectResult.get()
    }
}

import Foundation

struct PlexLoginSession {
    let id: Int
    let code: String
    let expiresAt: Date
}

final class PlexConnector: MediaConnector {
    let providerID: MediaProviderID = .plex

    private let client: PlexClient
    private let store: PlexSessionStore
    private var connection: PlexConnectionSummary?

    init(
        client: PlexClient = PlexClient(),
        store: PlexSessionStore = PlexSessionStore()
    ) {
        self.client = client
        self.store = store
    }

    func restoreConnection() async throws -> ConnectedServer? {
        guard store.userToken != nil else { return nil }
        return try await refreshConnection()
    }

    func refreshConnection() async throws -> ConnectedServer {
        guard let userToken = store.userToken else {
            throw MediaConnectorError.unavailable
        }

        let summary = try await client.connect(
            userToken: userToken,
            preferredServerID: store.serverIdentifier
        )

        store.serverIdentifier = summary.serverID
        connection = summary
        return summary.connectedServer(providerID: providerID)
    }

    func disconnect() {
        connection = nil
        store.clear()
    }

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        let libraryType: String
        switch library.defaultItemKind {
        case .series:
            libraryType = "show"
        case .movie:
            libraryType = "movie"
        case .season, .episode, .other:
            libraryType = "other"
        }

        let items = try await client.libraryItems(
            for: PlexLibraryContext(
                id: library.id,
                title: library.title,
                type: libraryType,
                agent: nil
            ),
            connection: connection
        )

        return items.map {
            $0.mediaItem(
                providerID: providerID,
                serverID: connection.serverID,
                serverURL: connection.serverURL,
                serverToken: connection.serverToken,
                fallbackKind: library.defaultItemKind
            )
        }
    }

    func loadChildren(for item: MediaItem) async throws -> [MediaItem] {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        let fallbackKind: MediaItemKind = switch item.kind {
        case .series:
            .season
        case .season:
            .episode
        case .movie, .episode, .other:
            .other
        }

        let children = try await client.children(for: item.id, connection: connection)

        return children.map {
            $0.mediaItem(
                providerID: providerID,
                serverID: connection.serverID,
                serverURL: connection.serverURL,
                serverToken: connection.serverToken,
                fallbackKind: fallbackKind
            )
        }
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        return try await client.playbackOptions(for: id.itemID, connection: connection)
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection?) async throws -> URL {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        return try await client.playbackURL(
            for: id.itemID,
            connection: connection,
            selection: selection
        )
    }

    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        try await client.reportTimeline(
            for: id.itemID,
            connection: connection,
            state: state.plexState,
            time: time,
            duration: duration,
            sessionID: sessionID
        )
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async throws {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        try await client.scrobble(for: id.itemID, connection: connection)
    }

    func beginLogin() async throws -> PlexLoginSession {
        let pin = try await client.createPin()
        return PlexLoginSession(
            id: pin.id,
            code: pin.code,
            expiresAt: Date().addingTimeInterval(TimeInterval(pin.expiresIn ?? 900))
        )
    }

    func completeLoginIfAuthorized(session: PlexLoginSession) async throws -> ConnectedServer? {
        guard let userToken = try await client.checkPin(id: session.id) else {
            return nil
        }

        store.userToken = userToken
        return try await refreshConnection()
    }
}

private extension MediaPlaybackTimelineState {
    var plexState: PlexClient.TimelineState {
        switch self {
        case .stopped:
            return .stopped
        case .buffering:
            return .buffering
        case .playing:
            return .playing
        case .paused:
            return .paused
        }
    }
}

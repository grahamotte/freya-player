import Foundation

protocol JellyfinConnecting: MediaConnector {
    var hasSavedConnection: Bool { get }

    func connect(serverURL: String, username: String, password: String) async throws -> ConnectedServer
}

final class JellyfinConnector: JellyfinConnecting {
    let providerID: MediaProviderID = .jellyfin
    private let client: JellyfinClient
    private let store: JellyfinSessionStore
    private var connection: JellyfinConnectionSummary?
    private var playbackContexts: [String: JellyfinPlaybackContext] = [:]

    init(
        client: JellyfinClient = JellyfinClient(),
        store: JellyfinSessionStore = JellyfinSessionStore()
    ) {
        self.client = client
        self.store = store
    }

    var hasSavedConnection: Bool {
        store.hasSavedConnection
    }

    func restoreConnection() async throws -> ConnectedServer? {
        guard store.hasSavedConnection else { return nil }
        return try await refreshConnection()
    }

    func refreshConnection() async throws -> ConnectedServer {
        guard let serverURL = connection?.serverURL ?? store.serverURL,
              let accessToken = connection?.accessToken ?? store.accessToken,
              let userID = connection?.userID ?? store.userID else {
            throw MediaConnectorError.unavailable
        }

        let summary = try await client.connection(
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            fallbackUserName: connection?.userName ?? store.userName
        )

        store.serverURL = summary.serverURL
        store.userID = summary.userID
        store.userName = summary.userName
        store.accessToken = summary.accessToken
        connection = summary
        return summary.connectedServer(providerID: providerID)
    }

    func disconnect() {
        connection = nil
        playbackContexts.removeAll()
        store.clear()
    }

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        return try await client.libraryItems(
            for: library,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID
        )
        .map {
            $0.mediaItem(
                providerID: providerID,
                serverID: connection.serverID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                fallbackKind: library.defaultItemKind
            )
        }
    }

    func loadItem(_ item: MediaItem) async throws -> MediaItem {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        return try await client.item(
            for: item.id,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID
        )
        .mediaItem(
            providerID: providerID,
            serverID: connection.serverID,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            fallbackKind: item.kind
        )
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

        return try await client.children(
            for: item,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID
        )
        .map {
            $0.mediaItem(
                providerID: providerID,
                serverID: connection.serverID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                fallbackKind: fallbackKind
            )
        }
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        let playbackInfo = try await client.playbackInfo(
            for: id.itemID,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID,
            selection: nil
        )

        guard let mediaSource = playbackInfo.mediaSources.first else {
            return nil
        }

        let streams = mediaSource.mediaStreams ?? []
        let videoHeight = streams.first(where: { $0.type == "Video" })?.height
        let transcodesBoth = !mediaSource.supportsDirectPlay && !mediaSource.supportsDirectStream
        let transcodesAudio = PlatformMetadata.requiresTranscodedPlaybackAudio || transcodesBoth
        let audioOptions = streams
            .filter { $0.type == "Audio" }
            .map {
                let canDirectStream = ["aac", "mp3"].contains($0.codec?.lowercased() ?? "")
                return MediaPlaybackOption(
                    id: String($0.index),
                    title: $0.displayTitle ?? $0.language ?? "Audio \($0.index)",
                    transcodingTitle: transcodesAudio || !canDirectStream ? "AAC" : nil
                )
            }
        let selectedAudioID = mediaSource.defaultAudioStreamIndex.map(String.init) ?? audioOptions.first?.id
        let defaultAudioTranscoding = selectedAudioID.flatMap { audioID in
            audioOptions.first(where: { $0.id == audioID })?.transcodingTitle
        }

        return MediaPlaybackOptions(
            videoHeight: videoHeight,
            qualityOptions: MediaPlaybackQuality.transcodingOptions(forVideoHeight: videoHeight),
            audioOptions: audioOptions,
            subtitleOptions: streams
                .filter { $0.type == "Subtitle" }
                .map {
                    MediaPlaybackOption(
                        id: String($0.index),
                        title: $0.displayTitle ?? $0.language ?? "Subtitle \($0.index)"
                    )
                },
            selectedAudioID: selectedAudioID,
            selectedSubtitleID: mediaSource.defaultSubtitleStreamIndex.map(String.init),
            defaultVideoTranscoding: transcodesBoth ? "H.264" : nil,
            defaultAudioTranscoding: defaultAudioTranscoding
        )
    }

    func playbackURL(
        for id: MediaPlaybackID,
        selection: MediaPlaybackSelection?,
        sessionID _: String,
        offsetMilliseconds: Int?
    ) async throws -> MediaPlaybackResource {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        let playbackInfo = try await client.playbackInfo(
            for: id.itemID,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID,
            selection: selection
        )

        let (resource, method, mediaSourceID) = try client.playbackURL(
            for: id.itemID,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            playbackInfo: playbackInfo,
            selection: selection,
            offsetMilliseconds: offsetMilliseconds
        )

        playbackContexts[id.itemID] = JellyfinPlaybackContext(
            method: method,
            mediaSourceID: mediaSourceID,
            playSessionID: playbackInfo.playSessionId
        )

        return resource
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

        let context = playbackContexts[id.itemID] ?? .init(
            method: .directPlay,
            mediaSourceID: nil,
            playSessionID: nil
        )

        switch state {
        case .stopped:
            try await client.reportPlaybackStopped(
                for: id.itemID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                userID: connection.userID,
                mediaSourceID: context.mediaSourceID,
                playSessionID: context.playSessionID,
                time: time
            )
            playbackContexts[id.itemID] = nil
        case .buffering, .playing, .paused:
            try await client.reportPlaybackProgress(
                for: id.itemID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                playbackMethod: context.method,
                mediaSourceID: context.mediaSourceID,
                playSessionID: context.playSessionID,
                time: time,
                isPaused: state == .paused
            )
        }
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async throws {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        try await client.markPlayed(
            itemID: id.itemID,
            serverURL: connection.serverURL,
            accessToken: connection.accessToken,
            userID: connection.userID
        )
    }

    func setWatchStatus(for id: MediaPlaybackID, isWatched: Bool) async throws {
        guard let connection else {
            throw MediaConnectorError.unavailable
        }

        if isWatched {
            try await client.markPlayed(
                itemID: id.itemID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                userID: connection.userID
            )
        } else {
            try await client.markUnplayed(
                itemID: id.itemID,
                serverURL: connection.serverURL,
                accessToken: connection.accessToken,
                userID: connection.userID
            )
        }
    }

    func connect(serverURL: String, username: String, password: String) async throws -> ConnectedServer {
        let (auth, resolvedServerURL) = try await client.authenticate(serverURL: serverURL, username: username, password: password)

        do {
            let summary = try await client.connection(
                serverURL: resolvedServerURL,
                accessToken: auth.accessToken,
                userID: auth.user.id,
                fallbackUserName: auth.user.name ?? username
            )
            store.serverURL = summary.serverURL
            store.userID = summary.userID
            store.userName = summary.userName
            store.accessToken = summary.accessToken
            connection = summary
            return summary.connectedServer(providerID: providerID)
        } catch {
            disconnect()
            throw error
        }
    }
}

private struct JellyfinPlaybackContext {
    let method: JellyfinPlaybackMethod
    let mediaSourceID: String?
    let playSessionID: String?
}

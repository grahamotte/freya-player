import Foundation

final class PlexClient {
    enum TimelineState: String {
        case stopped
        case buffering
        case playing
        case paused
    }

    private let session: URLSession
    private let defaults: any DefaultsStore
    private let bundle: Bundle
    private let clientIdentifier: String
    private var playbackMetadataCache: [String: PlexPlaybackMetadata] = [:]
    private let hlsProfileExtra = [
        "add-transcode-target(type=videoProfile&context=streaming&protocol=hls&container=mpegts&videoCodec=h264&audioCodec=aac&replace=true)",
        "add-transcode-target(type=subtitleProfile&context=all&protocol=hls&container=webvtt&subtitleCodec=webvtt)"
    ].joined(separator: "+")

    init(
        session: URLSession = .shared,
        defaults: any DefaultsStore = UserDefaults.standard,
        bundle: Bundle = .main
    ) {
        self.session = session
        self.defaults = defaults
        self.bundle = bundle
        self.clientIdentifier = Self.loadClientIdentifier(defaults: defaults)
    }

    func clearCache() {
        playbackMetadataCache.removeAll()
    }

    func createPin() async throws -> PlexPin {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins")!)
        request.httpMethod = "POST"
        applyPlexHeaders(to: &request)
        return try await send(request)
    }

    func checkPin(id: Int) async throws -> String? {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins/\(id)")!)
        applyPlexHeaders(to: &request)
        return try await send(request, as: PlexPin.self).authToken
    }

    func connect(userToken: String, preferredServerID: String?) async throws -> PlexConnectionSummary {
        let user = try await fetchUser(userToken: userToken)
        let servers = try await fetchServers(userToken: userToken)
        let orderedServers = orderServers(servers, preferredServerID: preferredServerID)

        for server in orderedServers {
            let serverToken = server.accessToken ?? userToken

            for connection in orderConnections(server.connections ?? []) {
                do {
                    let libraries = try await fetchLibraries(baseURL: connection.uri, token: serverToken)
                    let sections = try await fetchLibrarySections(
                        libraries: libraries,
                        baseURL: connection.uri,
                        token: serverToken
                    )

                    return PlexConnectionSummary(
                        serverID: server.clientIdentifier,
                        serverName: server.name,
                        serverURL: connection.uri,
                        serverToken: serverToken,
                        accountName: user.displayName,
                        isLocal: connection.local,
                        libraries: sections
                    )
                } catch {
                    continue
                }
            }
        }

        throw PlexError.noReachableServer
    }

    func playbackOptions(for ratingKey: String, connection: PlexConnectionSummary) async throws -> MediaPlaybackOptions? {
        let metadata = try await playbackMetadata(for: ratingKey, connection: connection)
        return metadata.playbackOptions()
    }

    func playbackURL(
        for ratingKey: String,
        connection: PlexConnectionSummary,
        selection: MediaPlaybackSelection? = nil,
        sessionID: String,
        offsetMilliseconds: Int? = nil
    ) async throws -> MediaPlaybackResource {
        let metadata = try await playbackMetadata(for: ratingKey, connection: connection)
        let requiresTranscodedAudio = PlatformMetadata.requiresTranscodedPlaybackAudio
        let directStreamAudio = !requiresTranscodedAudio && metadata.canDirectStreamAudio(selection?.audioID)

        if let selection,
           (selection.audioID != nil || selection.subtitleID != nil),
           let partID = metadata.selectedPartID {
            try await setStreamSelection(
                partID: partID,
                audioStreamID: selection.audioID ?? metadata.playbackOptions()?.selectedAudioID,
                subtitleStreamID: selection.subtitleID,
                connection: connection
            )

            try await preparePlaybackSession(
                ratingKey: ratingKey,
                connection: connection,
                quality: selection.quality,
                sessionID: sessionID,
                offsetMilliseconds: offsetMilliseconds,
                directStreamAudio: directStreamAudio
            )

            guard let url = transcodedMovieStreamURL(
                for: ratingKey,
                connection: connection,
                quality: selection.quality,
                sessionID: sessionID,
                offsetMilliseconds: offsetMilliseconds,
                directStreamAudio: directStreamAudio
            ) else {
                throw PlexError.invalidURL
            }

            return MediaPlaybackResource(
                url: url,
                localStartOffsetMilliseconds: nil,
                reloadsForSeek: true,
                remoteSessionID: sessionID,
                descriptionPrefix: metadata.transcodingDescription(
                    quality: selection.quality,
                    directStreamAudio: directStreamAudio,
                    hasSubtitles: selection.subtitleID != nil
                )
            )
        }

        if !requiresTranscodedAudio,
           selection?.quality ?? .automatic == .automatic,
           let url = directPlayURL(
               from: metadata,
               connection: connection,
               videoBitrateLimit: connection.automaticVideoBitrateLimit
           ) {
            return MediaPlaybackResource(
                url: url,
                localStartOffsetMilliseconds: offsetMilliseconds
            )
        }

        try await preparePlaybackSession(
            ratingKey: ratingKey,
            connection: connection,
            quality: selection?.quality ?? .automatic,
            sessionID: sessionID,
            offsetMilliseconds: offsetMilliseconds,
            directStreamAudio: directStreamAudio
        )

        guard let url = transcodedMovieStreamURL(
            for: ratingKey,
            connection: connection,
            quality: selection?.quality ?? .automatic,
            sessionID: sessionID,
            offsetMilliseconds: offsetMilliseconds,
            directStreamAudio: directStreamAudio
        ) else {
            throw PlexError.invalidURL
        }

        let quality = selection?.quality ?? .automatic
        return MediaPlaybackResource(
            url: url,
            localStartOffsetMilliseconds: nil,
            reloadsForSeek: true,
            remoteSessionID: sessionID,
            descriptionPrefix: metadata.transcodingDescription(
                quality: quality,
                maxVideoBitrate: quality.maxVideoBitrate ?? connection.automaticVideoBitrateLimit,
                directStreamAudio: directStreamAudio,
                hasSubtitles: false
            )
        )
    }

    func children(for ratingKey: String, connection: PlexConnectionSummary) async throws -> [PlexMediaItem] {
        try await fetchMetadataItems(
            path: "/library/metadata/\(ratingKey)/children",
            token: connection.serverToken,
            baseURL: connection.serverURL,
            extraQueryItems: [URLQueryItem(name: "sort", value: "index:asc")]
        )
    }

    func item(for ratingKey: String, connection: PlexConnectionSummary) async throws -> PlexMediaItem {
        let items = try await fetchMetadataItems(
            path: "/library/metadata/\(ratingKey)",
            token: connection.serverToken,
            baseURL: connection.serverURL,
            extraQueryItems: [URLQueryItem(name: "includeElements", value: "Media,Part,Stream")]
        )

        guard let item = items.first else {
            throw PlexError.invalidResponse
        }

        return item
    }

    func reportTimeline(
        for ratingKey: String,
        connection: PlexConnectionSummary,
        state: TimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws {
        guard var components = URLComponents(string: "\(connection.serverURL)/:/timeline") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "ratingKey", value: ratingKey),
            URLQueryItem(name: "state", value: state.rawValue),
            URLQueryItem(name: "time", value: String(max(time, 0))),
            duration.map { URLQueryItem(name: "duration", value: String(max($0, 0))) },
            state == .stopped ? URLQueryItem(name: "continuing", value: "0") : nil,
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]
        .compactMap { $0 }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        applyPlexHeaders(to: &request, token: connection.serverToken, sessionID: sessionID)
        try await sendVoid(request, priority: .playback)
    }

    func stopPlaybackSession(
        _ sessionID: String,
        connection: PlexConnectionSummary
    ) async throws {
        guard var components = URLComponents(
            string: "\(connection.serverURL)/video/:/transcode/universal/stop"
        ) else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "session", value: sessionID),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: connection.serverToken)
        try await sendVoid(request, priority: .playback)
    }

    func scrobble(
        for ratingKey: String,
        connection: PlexConnectionSummary
    ) async throws {
        guard var components = URLComponents(string: "\(connection.serverURL)/:/scrobble") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "identifier", value: "com.plexapp.plugins.library"),
            URLQueryItem(name: "key", value: ratingKey),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        applyPlexHeaders(to: &request, token: connection.serverToken)
        try await sendVoid(request)
    }

    func unscrobble(
        for ratingKey: String,
        connection: PlexConnectionSummary
    ) async throws {
        guard var components = URLComponents(string: "\(connection.serverURL)/:/unscrobble") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "identifier", value: "com.plexapp.plugins.library"),
            URLQueryItem(name: "key", value: ratingKey),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        applyPlexHeaders(to: &request, token: connection.serverToken)
        try await sendVoid(request)
    }

    func libraryItems(for library: PlexLibraryContext, connection: PlexConnectionSummary) async throws -> [PlexMediaItem] {
        let items = try await fetchMetadataItems(
            path: "/library/sections/\(library.id)/all",
            token: connection.serverToken,
            baseURL: connection.serverURL,
            pageSize: 500
        )

        return items.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func setStreamSelection(
        partID: String,
        audioStreamID: String?,
        subtitleStreamID: String?,
        connection: PlexConnectionSummary
    ) async throws {
        guard var components = URLComponents(string: "\(connection.serverURL)/library/parts/\(partID)") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "allParts", value: "0"),
            URLQueryItem(name: "audioStreamID", value: audioStreamID),
            URLQueryItem(name: "subtitleStreamID", value: subtitleStreamID ?? "0"),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        applyPlexHeaders(to: &request, token: connection.serverToken)
        try await sendVoid(request, priority: .playback)
    }

    private func transcodedMovieStreamURL(
        for ratingKey: String,
        connection: PlexConnectionSummary,
        quality: MediaPlaybackQuality,
        sessionID: String,
        offsetMilliseconds: Int?,
        directStreamAudio: Bool
    ) -> URL? {
        guard var components = URLComponents(
            string: "\(connection.serverURL)/video/:/transcode/universal/start.m3u8"
        ) else {
            return nil
        }

        components.queryItems = playbackQueryItems(
            for: ratingKey,
            connection: connection,
            quality: quality,
            sessionID: sessionID,
            offsetMilliseconds: offsetMilliseconds,
            directStreamAudio: directStreamAudio
        )

        return components.url
    }

    private func preparePlaybackSession(
        ratingKey: String,
        connection: PlexConnectionSummary,
        quality: MediaPlaybackQuality,
        sessionID: String,
        offsetMilliseconds: Int?,
        directStreamAudio: Bool
    ) async throws {
        guard var components = URLComponents(
            string: "\(connection.serverURL)/video/:/transcode/universal/decision"
        ) else {
            throw PlexError.invalidURL
        }

        components.queryItems = playbackQueryItems(
            for: ratingKey,
            connection: connection,
            quality: quality,
            sessionID: sessionID,
            offsetMilliseconds: offsetMilliseconds,
            directStreamAudio: directStreamAudio
        )

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: connection.serverToken)
        let response: PlexMetadataContainer<PlexPlaybackDecisionMetadata> = try await send(
            request,
            priority: .playback
        )
        guard response.mediaContainer.metadata?.isEmpty == false else {
            let details = response.mediaContainer.playbackDecisionDetails
            throw details.isEmpty ? PlexError.invalidResponse : PlexError.playbackFailed(details.joined(separator: "\n"))
        }
    }

    private func playbackQueryItems(
        for ratingKey: String,
        connection: PlexConnectionSummary,
        quality: MediaPlaybackQuality,
        sessionID: String,
        offsetMilliseconds: Int?,
        directStreamAudio: Bool
    ) -> [URLQueryItem] {
        let maxVideoBitrate = quality.maxVideoBitrate ?? connection.automaticVideoBitrateLimit

        return [
            URLQueryItem(name: "path", value: "/library/metadata/\(ratingKey)"),
            URLQueryItem(name: "mediaIndex", value: "0"),
            URLQueryItem(name: "partIndex", value: "0"),
            URLQueryItem(name: "protocol", value: "hls"),
            offsetMilliseconds.map { URLQueryItem(name: "offset", value: String($0 / 1000)) },
            maxVideoBitrate.map { URLQueryItem(name: "maxVideoBitrate", value: String($0)) },
            quality.videoResolution.map { URLQueryItem(name: "videoResolution", value: $0) },
            URLQueryItem(name: "copyts", value: "1"),
            URLQueryItem(name: "fastSeek", value: "1"),
            URLQueryItem(name: "subtitles", value: "segmented"),
            URLQueryItem(name: "directPlay", value: "0"),
            URLQueryItem(name: "directStream", value: "1"),
            URLQueryItem(name: "directStreamAudio", value: directStreamAudio ? "1" : "0"),
            URLQueryItem(name: "advancedSubtitles", value: "text"),
            URLQueryItem(name: "transcodeSessionId", value: sessionID),
            URLQueryItem(name: "X-Plex-Client-Profile-Extra", value: hlsProfileExtra),
            URLQueryItem(name: "X-Plex-Client-Profile-Name", value: "iOS"),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: clientIdentifier),
            URLQueryItem(name: "X-Plex-Product", value: "Freya Player"),
            URLQueryItem(name: "X-Plex-Version", value: clientVersion),
            URLQueryItem(name: "X-Plex-Platform", value: PlatformMetadata.plexPlatformName),
            URLQueryItem(name: "X-Plex-Device", value: PlatformMetadata.deviceName),
            URLQueryItem(name: "X-Plex-Device-Name", value: "Freya Player")
        ]
        .compactMap { $0 }
    }

    private func directPlayURL(
        from metadata: PlexPlaybackMetadata,
        connection: PlexConnectionSummary,
        videoBitrateLimit: Int?
    ) -> URL? {
        guard let partKey = metadata.media?.first(where: { media in
            guard media.isDirectPlayable else { return false }
            return videoBitrateLimit.map { (media.bitrate ?? .max) <= $0 } ?? true
        })?.parts?.first?.key,
              var components = URLComponents(string: "\(connection.serverURL)\(partKey)") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "download", value: "0"),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]
        return components.url
    }

    private func fetchPlaybackMetadata(
        ratingKey: String,
        baseURL: String,
        token: String,
        priority: RequestScheduler.Priority = .normal
    ) async throws -> PlexPlaybackMetadata {
        guard var components = URLComponents(string: "\(baseURL)/library/metadata/\(ratingKey)") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "includeElements", value: "Media,Part,Stream"),
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: token)

        let response: PlexMetadataContainer<PlexPlaybackMetadata> = try await send(request, priority: priority)

        guard let metadata = response.mediaContainer.metadata?.first else {
            throw PlexError.invalidResponse
        }

        return metadata
    }

    private func playbackMetadata(
        for ratingKey: String,
        connection: PlexConnectionSummary
    ) async throws -> PlexPlaybackMetadata {
        let key = "\(connection.serverID):\(ratingKey)"
        if let metadata = playbackMetadataCache[key] { return metadata }
        let metadata = try await fetchPlaybackMetadata(
            ratingKey: ratingKey,
            baseURL: connection.serverURL,
            token: connection.serverToken,
            priority: .playback
        )
        playbackMetadataCache[key] = metadata
        return metadata
    }

    private func fetchUser(userToken: String) async throws -> PlexUser {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/user")!)
        applyPlexHeaders(to: &request, token: userToken)
        return try await send(request)
    }

    private func fetchServers(userToken: String) async throws -> [PlexServer] {
        var components = URLComponents(string: "https://plex.tv/api/v2/resources")!
        components.queryItems = [URLQueryItem(name: "includeHttps", value: "1")]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: userToken)

        let resources: [PlexServer] = try await send(request)
        return resources.filter { $0.provides.contains("server") }
    }

    private func fetchLibraries(baseURL: String, token: String) async throws -> [PlexLibrary] {
        guard var components = URLComponents(string: "\(baseURL)/library/sections") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: token)

        let response: PlexDirectoryContainer<PlexLibrary> = try await send(request)
        return response.mediaContainer.directory ?? []
    }

    private func fetchLibrarySections(
        libraries: [PlexLibrary],
        baseURL: String,
        token: String
    ) async throws -> [PlexLibrarySection] {
        var sections: [PlexLibrarySection] = []

        for library in libraries {
            let items = (try? await fetchItems(for: library, baseURL: baseURL, token: token)) ?? []
            sections.append(
                PlexLibrarySection(
                    id: library.key,
                    title: library.title,
                    type: library.type,
                    agent: library.agent,
                    items: items
                )
            )
        }

        return sections
    }

    private func fetchItems(for library: PlexLibrary, baseURL: String, token: String) async throws -> [PlexMediaItem] {
        switch library.type {
        case "show":
            return try await fetchSectionItems(
                path: "/library/sections/\(library.key)/all",
                token: token,
                baseURL: baseURL,
                extraQueryItems: [
                    URLQueryItem(name: "type", value: "2"),
                    URLQueryItem(name: "sort", value: "addedAt:desc")
                ]
            )
        case "movie":
            return try await fetchSectionItems(
                path: "/library/sections/\(library.key)/recentlyAdded",
                token: token,
                baseURL: baseURL,
                extraQueryItems: [URLQueryItem(name: "type", value: "1")]
            )
        default:
            return try await fetchSectionItems(
                path: "/library/sections/\(library.key)/recentlyAdded",
                token: token,
                baseURL: baseURL
            )
        }
    }

    private func fetchSectionItems(
        path: String,
        token: String,
        baseURL: String,
        extraQueryItems: [URLQueryItem] = []
    ) async throws -> [PlexMediaItem] {
        try await fetchMetadataItems(
            path: path,
            token: token,
            baseURL: baseURL,
            extraQueryItems: extraQueryItems
        )
    }

    private func fetchMetadataItems(
        path: String,
        token: String,
        baseURL: String,
        extraQueryItems: [URLQueryItem] = [],
        pageSize: Int = 200
    ) async throws -> [PlexMediaItem] {
        var items: [PlexMediaItem] = []
        var start = 0

        while true {
            guard var components = URLComponents(string: "\(baseURL)\(path)") else {
                throw PlexError.invalidURL
            }

            components.queryItems = extraQueryItems + [
                URLQueryItem(name: "X-Plex-Container-Start", value: String(start)),
                URLQueryItem(name: "X-Plex-Container-Size", value: String(pageSize)),
                URLQueryItem(name: "X-Plex-Token", value: token)
            ]

            var request = URLRequest(url: components.url!)
            applyPlexHeaders(to: &request, token: token)

            let response: PlexMetadataContainer<PlexMediaItem> = try await send(request)
            let batch = response.mediaContainer.metadata ?? []
            items += batch

            let totalSize = response.mediaContainer.totalSize ?? batch.count
            start += batch.count

            if batch.isEmpty || start >= totalSize || batch.count < pageSize {
                return items
            }
        }
    }

    private func send<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type = T.self,
        priority: RequestScheduler.Priority = .normal
    ) async throws -> T {
        let (data, response) = try await session.gatedData(for: request, priority: priority)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw PlexError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sendVoid(
        _ request: URLRequest,
        priority: RequestScheduler.Priority = .normal
    ) async throws {
        let (_, response) = try await session.gatedData(for: request, priority: priority)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw PlexError.requestFailed(httpResponse.statusCode)
        }
    }

    private func applyPlexHeaders(to request: inout URLRequest, token: String? = nil, sessionID: String? = nil) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("Freya Player", forHTTPHeaderField: "X-Plex-Product")
        request.setValue(clientVersion, forHTTPHeaderField: "X-Plex-Version")
        request.setValue(PlatformMetadata.plexPlatformName, forHTTPHeaderField: "X-Plex-Platform")
        request.setValue(PlatformMetadata.deviceName, forHTTPHeaderField: "X-Plex-Device")
        request.setValue("Freya Player", forHTTPHeaderField: "X-Plex-Device-Name")

        if let token {
            request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        }

        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "X-Plex-Session-Identifier")
        }
    }

    private func orderServers(_ servers: [PlexServer], preferredServerID: String?) -> [PlexServer] {
        servers.sorted { lhs, rhs in
            score(server: lhs, preferredServerID: preferredServerID) > score(server: rhs, preferredServerID: preferredServerID)
        }
    }

    private func orderConnections(_ connections: [PlexServerConnection]) -> [PlexServerConnection] {
        connections.sorted { lhs, rhs in
            score(connection: lhs) > score(connection: rhs)
        }
    }

    private func score(server: PlexServer, preferredServerID: String?) -> Int {
        var score = 0

        if server.clientIdentifier == preferredServerID {
            score += 100
        }
        if server.owned == true {
            score += 10
        }
        if server.accessToken != nil {
            score += 1
        }

        return score
    }

    private func score(connection: PlexServerConnection) -> Int {
        var score = 0

        if connection.local {
            score += 10
        }
        if connection.protocolType == "https" {
            score += 5
        }
        if !connection.relay {
            score += 2
        }

        return score
    }

    private var clientVersion: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func loadClientIdentifier(defaults: any DefaultsStore) -> String {
        let key = "plex.client.identifier"

        if let existing = defaults.string(forKey: key) {
            return existing
        }

        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: key)
        return identifier
    }
}

private enum PlexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case playbackFailed(String)
    case noReachableServer

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Plex returned an invalid connection address."
        case .invalidResponse:
            return "Plex returned a response Freya couldn't read."
        case .requestFailed(let statusCode):
            return "Plex returned HTTP \(statusCode). Please try again."
        case .playbackFailed(let details):
            return "Plex could not create a playable stream.\n\n\(details)"
        case .noReachableServer:
            return "Plex approved Freya, but we couldn't reach a Plex Media Server for this account. Check that the server is online and reachable from this device."
        }
    }
}

private struct PlexUser: Decodable {
    let title: String?
    let friendlyName: String?
    let username: String?
    let email: String?

    var displayName: String {
        friendlyName ?? title ?? username ?? email ?? "Plex"
    }
}

private struct PlexServer: Decodable {
    let name: String
    let clientIdentifier: String
    let provides: String
    let accessToken: String?
    let owned: Bool?
    let connections: [PlexServerConnection]?
}

private struct PlexServerConnection: Decodable {
    let protocolType: String
    let uri: String
    let local: Bool
    let relay: Bool

    private enum CodingKeys: String, CodingKey {
        case protocolType = "protocol"
        case uri
        case local
        case relay
    }
}

private struct PlexDirectoryContainer<Item: Decodable>: Decodable {
    let mediaContainer: MediaContainer

    struct MediaContainer: Decodable {
        let directory: [Item]?

        private enum CodingKeys: String, CodingKey {
            case directory = "Directory"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private struct PlexMetadataContainer<Item: Decodable>: Decodable {
    let mediaContainer: MediaContainer

    struct MediaContainer: Decodable {
        let metadata: [Item]?
        let totalSize: Int?
        let generalDecisionCode: Int?
        let generalDecisionText: String?
        let directPlayDecisionCode: Int?
        let directPlayDecisionText: String?
        let transcodeDecisionCode: Int?
        let transcodeDecisionText: String?

        var playbackDecisionDetails: [String] {
            [
                decision("General", code: generalDecisionCode, text: generalDecisionText),
                decision("Direct play", code: directPlayDecisionCode, text: directPlayDecisionText),
                decision("Transcode", code: transcodeDecisionCode, text: transcodeDecisionText)
            ].compactMap { $0 }
        }

        private enum CodingKeys: String, CodingKey {
            case metadata = "Metadata"
            case totalSize
            case generalDecisionCode, generalDecisionText
            case directPlayDecisionCode, directPlayDecisionText
            case transcodeDecisionCode, transcodeDecisionText
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            metadata = try container.decodeIfPresent([Item].self, forKey: .metadata)
            totalSize = try container.decodeLossyIntIfPresent(forKey: .totalSize)
            generalDecisionCode = try container.decodeLossyIntIfPresent(forKey: .generalDecisionCode)
            generalDecisionText = try container.decodeIfPresent(String.self, forKey: .generalDecisionText)
            directPlayDecisionCode = try container.decodeLossyIntIfPresent(forKey: .directPlayDecisionCode)
            directPlayDecisionText = try container.decodeIfPresent(String.self, forKey: .directPlayDecisionText)
            transcodeDecisionCode = try container.decodeLossyIntIfPresent(forKey: .transcodeDecisionCode)
            transcodeDecisionText = try container.decodeIfPresent(String.self, forKey: .transcodeDecisionText)
        }

        private func decision(_ name: String, code: Int?, text: String?) -> String? {
            guard let text, !text.isEmpty else { return nil }
            return code.map { "\(name) (\($0)): \(text)" } ?? "\(name): \(text)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private struct PlexPlaybackMetadata: Decodable {
    let media: [Media]?

    var hasSelectableStreams: Bool {
        media?.contains(where: \.hasSelectableStreams) == true
    }

    var selectedPartID: String? {
        media?.first(where: { $0.parts?.isEmpty == false })?.parts?.first?.id
    }

    func canDirectStreamAudio(_ audioID: String?) -> Bool {
        guard !PlatformMetadata.prefersAACPlaybackAudio else {
            let media = media?.first(where: { $0.parts?.isEmpty == false })
            let streams = media?.parts?.first?.streams
            let stream = streams?.first { stream in
                guard stream.streamType == 2 else { return false }
                return audioID.map { $0 == stream.id } ?? stream.selected == true
            }
            return ["aac", "mp3"].contains((stream?.codec ?? media?.audioCodec)?.lowercased())
        }
        return true
    }

    func playbackOptions() -> MediaPlaybackOptions? {
        guard let media = media?.first(where: { $0.parts?.isEmpty == false }),
              let part = media.parts?.first else {
            return nil
        }

        let audioOptions = part.audioOptions
        let subtitleOptions = part.subtitleOptions

        return MediaPlaybackOptions(
            qualityOptions: MediaPlaybackQuality.allCases,
            audioOptions: audioOptions,
            subtitleOptions: subtitleOptions,
            selectedAudioID: part.selectedAudioID ?? audioOptions.first?.id,
            selectedSubtitleID: part.selectedSubtitleID
        )
    }

    func transcodingDescription(
        quality: MediaPlaybackQuality,
        maxVideoBitrate: Int? = nil,
        directStreamAudio: Bool,
        hasSubtitles: Bool
    ) -> String? {
        guard let media = media?.first else { return nil }
        var details: [String] = []

        if quality != .automatic
            || !media.canDirectStreamVideo
            || maxVideoBitrate.map({ (media.bitrate ?? .max) > $0 }) == true {
            details.append([quality == .automatic ? nil : quality.title, "H.264 video"].compactMap { $0 }.joined(separator: " "))
        }
        if !directStreamAudio { details.append("AAC audio") }
        if hasSubtitles { details.append("WebVTT subtitles") }

        return details.isEmpty ? nil : "Transcoding: \(details.joined(separator: " • "))"
    }

    private enum CodingKeys: String, CodingKey {
        case media = "Media"
    }

    struct Media: Decodable {
        let container: String?
        let videoCodec: String?
        let audioCodec: String?
        let bitrate: Int?
        let parts: [Part]?

        var hasSelectableStreams: Bool {
            parts?.contains(where: \.hasSelectableStreams) == true
        }

        var isDirectPlayable: Bool {
            guard let parts, !parts.isEmpty else { return false }
            return Self.supportedContainers.contains(container?.lowercased() ?? "")
                && Self.supportedVideoCodecs.contains(videoCodec?.lowercased() ?? "")
                && Self.supportedAudioCodecs.contains(audioCodec?.lowercased() ?? "")
                && parts.allSatisfy(\.canDirectPlay)
        }

        var canDirectStreamVideo: Bool {
            ["h264", "avc", "avc1"].contains(videoCodec?.lowercased() ?? "")
        }

        private static let supportedContainers = ["mp4", "m4v", "mov"]
        private static let supportedVideoCodecs = ["h264", "avc", "avc1", "hevc", "h265", "hvc1"]
        private static var supportedAudioCodecs: [String] {
            PlatformMetadata.prefersAACPlaybackAudio ? ["aac", "mp3"] : ["aac", "ac3", "eac3", "mp3"]
        }

        private enum CodingKeys: String, CodingKey {
            case container
            case videoCodec
            case audioCodec
            case bitrate
            case parts = "Part"
        }
    }

    struct Part: Decodable {
        let id: String?
        let key: String
        let streams: [Stream]?

        var audioOptions: [MediaPlaybackOption] {
            streams?
                .filter { $0.streamType == 2 }
                .compactMap { stream in
                    guard let id = stream.id else { return nil }
                    return MediaPlaybackOption(id: id, title: stream.displayName)
                } ?? []
        }

        var subtitleOptions: [MediaPlaybackOption] {
            streams?
                .filter { $0.streamType == 3 }
                .compactMap { stream in
                    guard let id = stream.id else { return nil }
                    return MediaPlaybackOption(id: id, title: stream.displayName)
                } ?? []
        }

        var selectedAudioID: String? {
            streams?.first(where: { $0.streamType == 2 && $0.selected == true })?.id
        }

        var selectedSubtitleID: String? {
            streams?.first(where: { $0.streamType == 3 && $0.selected == true })?.id
        }

        var hasSelectableStreams: Bool {
            audioStreamCount > 1 || subtitleStreamCount > 0
        }

        var canDirectPlay: Bool {
            streams != nil && audioStreamCount <= 1
        }

        private var audioStreamCount: Int {
            streams?.filter { $0.streamType == 2 }.count ?? 0
        }

        private var subtitleStreamCount: Int {
            streams?.filter { $0.streamType == 3 }.count ?? 0
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeLossyStringIfPresent(forKey: .id)
            key = try container.decodeLossyString(forKey: .key)
            streams = try container.decodeIfPresent([Stream].self, forKey: .streams)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case key
            case streams = "Stream"
        }
    }

    struct Stream: Decodable {
        let id: String?
        let streamType: Int?
        let codec: String?
        let selected: Bool?
        let language: String?
        let title: String?
        let displayTitle: String?

        var displayName: String {
            displayTitle ?? title ?? language ?? fallbackTitle
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeLossyStringIfPresent(forKey: .id)
            streamType = try container.decodeLossyIntIfPresent(forKey: .streamType)
            codec = try container.decodeIfPresent(String.self, forKey: .codec)
            selected = try container.decodeLossyBoolIfPresent(forKey: .selected)
            language = try container.decodeIfPresent(String.self, forKey: .language)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            displayTitle = try container.decodeIfPresent(String.self, forKey: .displayTitle)
        }

        private var fallbackTitle: String {
            switch streamType {
            case 2:
                return "Audio"
            case 3:
                return "Subtitle"
            default:
                return "Track"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case streamType
            case codec
            case selected
            case language
            case title
            case displayTitle
        }
    }
}

private struct PlexPlaybackDecisionMetadata: Decodable {}

import Foundation

final class JellyfinClient {
    private let session: URLSession
    private let defaults: any DefaultsStore
    private let bundle: Bundle
    private let deviceID: String

    init(
        session: URLSession = .shared,
        defaults: any DefaultsStore = UserDefaults.standard,
        bundle: Bundle = .main
    ) {
        self.session = session
        self.defaults = defaults
        self.bundle = bundle
        self.deviceID = Self.loadDeviceID(defaults: defaults)
    }

    func authenticate(serverURL: String, username: String, password: String) async throws -> (JellyfinAuthenticationResult, String) {
        do {
            return try await performAuthentication(serverURL: normalize(serverURL: serverURL), username: username, password: password)
        } catch {
            guard !hasScheme(serverURL),
                  normalize(serverURL: serverURL).hasPrefix("https://") else {
                throw error
            }

            return try await performAuthentication(serverURL: normalize(serverURL: serverURL, scheme: "http"), username: username, password: password)
        }
    }

    func connection(
        serverURL: String,
        accessToken: String,
        userID: String,
        fallbackUserName: String?
    ) async throws -> JellyfinConnectionSummary {
        let publicInfo = try await fetchPublicSystemInfo(serverURL: serverURL, accessToken: accessToken)
        let libraries = try await fetchLibraries(serverURL: serverURL, accessToken: accessToken, userID: userID)
        let sessionID = try await fetchSessionID(serverURL: serverURL, accessToken: accessToken)

        return JellyfinConnectionSummary(
            serverID: publicInfo.id ?? "",
            serverName: publicInfo.serverName ?? "Jellyfin",
            serverURL: normalize(serverURL: serverURL),
            accessToken: accessToken,
            userID: userID,
            userName: fallbackUserName ?? "Jellyfin",
            sessionID: sessionID,
            libraries: libraries
        )
    }

    func libraryItems(
        for library: LibraryReference,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws -> [JellyfinItem] {
        try await fetchAllItems(
            serverURL: serverURL,
            accessToken: accessToken,
            queryItems: libraryQueryItems(for: library, userID: userID)
        )
    }

    func children(
        for item: MediaItem,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws -> [JellyfinItem] {
        let includeItemTypes: String? = switch item.kind {
        case .series:
            "Season"
        case .season:
            "Episode"
        case .movie, .episode, .other:
            nil
        }

        guard let includeItemTypes else { return [] }

        return try await fetchAllItems(
            serverURL: serverURL,
            accessToken: accessToken,
            queryItems: [
                URLQueryItem(name: "userId", value: userID),
                URLQueryItem(name: "parentId", value: item.id),
                URLQueryItem(name: "includeItemTypes", value: includeItemTypes),
                URLQueryItem(name: "fields", value: "Overview,DateCreated"),
                URLQueryItem(name: "enableUserData", value: "true"),
                URLQueryItem(name: "enableImages", value: "true"),
                URLQueryItem(name: "enableTotalRecordCount", value: "true"),
                URLQueryItem(name: "sortBy", value: item.kind == .season ? "ParentIndexNumber,IndexNumber" : "SortName"),
                URLQueryItem(name: "sortOrder", value: "Ascending")
            ]
        )
    }

    func item(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws -> JellyfinItem {
        var components = try URLComponents(
            url: url(serverURL: serverURL, path: "/Users/\(userID)/Items/\(itemID)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "Overview,DateCreated,MediaSources"),
            URLQueryItem(name: "enableUserData", value: "true"),
            URLQueryItem(name: "enableImages", value: "true")
        ]

        guard let url = components?.url else {
            throw MediaConnectorError.unavailable
        }

        var request = URLRequest(url: url)
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        return try await send(request)
    }

    func playbackInfo(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String,
        selection: MediaPlaybackSelection?
    ) async throws -> JellyfinPlaybackInfoResponse {
        var request = URLRequest(url: try url(serverURL: serverURL, path: "/Items/\(itemID)/PlaybackInfo"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            JellyfinPlaybackInfoBody(
                UserId: userID,
                MaxStreamingBitrate: selection?.quality.maxStreamingBitrate,
                AudioStreamIndex: selection?.audioID.flatMap(Int.init),
                SubtitleStreamIndex: selection?.subtitleID.flatMap(Int.init),
                EnableDirectPlay: selection?.quality == nil || selection?.quality == .automatic,
                EnableDirectStream: selection?.quality == nil || selection?.quality == .automatic,
                EnableTranscoding: true
            )
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        return try await send(request, priority: .playback)
    }

    func playbackURL(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        playbackInfo: JellyfinPlaybackInfoResponse,
        selection: MediaPlaybackSelection?,
        offsetMilliseconds: Int?
    ) throws -> (MediaPlaybackResource, JellyfinPlaybackMethod, String?) {
        guard let mediaSource = playbackInfo.mediaSources.first else {
            throw MediaConnectorError.unavailable
        }

        if selection?.quality ?? .automatic == .automatic,
           selection?.audioID == nil,
           selection?.subtitleID == nil,
           mediaSource.supportsDirectPlay,
           let url = directPlayURL(
               for: itemID,
               serverURL: serverURL,
               accessToken: accessToken,
               playbackInfo: playbackInfo,
               mediaSource: mediaSource
           ) {
            return (
                MediaPlaybackResource(url: url, localStartOffsetMilliseconds: offsetMilliseconds),
                .directPlay,
                mediaSource.id
            )
        }

        if !PlatformMetadata.prefersAACPlaybackAudio,
           let transcodingURL = mediaSource.transcodingURL,
           var components = URLComponents(string: normalize(serverURL: serverURL) + transcodingURL) {
            var queryItems = components.queryItems ?? []
            queryItems.removeAll { $0.name.caseInsensitiveCompare("startTimeTicks") == .orderedSame }
            queryItems.append(URLQueryItem(name: "api_key", value: accessToken))
            components.queryItems = queryItems
            guard let url = components.url else {
                throw MediaConnectorError.unavailable
            }
            return (
                MediaPlaybackResource(
                    url: url,
                    localStartOffsetMilliseconds: offsetMilliseconds,
                    descriptionPrefix: "Transcoding: H.264 video • AAC audio"
                ),
                .transcode,
                mediaSource.id
            )
        }

        guard var components = URLComponents(string: "\(normalize(serverURL: serverURL))/Videos/\(itemID)/master.m3u8") else {
            throw MediaConnectorError.unavailable
        }

        let selectedAudioIndex = selection?.audioID
        let selectedSubtitleIndex = selection?.subtitleID

        components.queryItems = [
            playbackInfo.playSessionId.map { URLQueryItem(name: "playSessionId", value: $0) },
            mediaSource.id.map { URLQueryItem(name: "mediaSourceId", value: $0) },
            selection?.quality.maxStreamingBitrate.map { URLQueryItem(name: "videoBitRate", value: String($0)) },
            selection?.quality.jellyfinMaxWidth.map { URLQueryItem(name: "maxWidth", value: $0) },
            selection?.quality.videoResolution.map { URLQueryItem(name: "maxHeight", value: $0) },
            selectedAudioIndex.map { URLQueryItem(name: "audioStreamIndex", value: $0) },
            selectedSubtitleIndex.map { URLQueryItem(name: "subtitleStreamIndex", value: $0) },
            selectedSubtitleIndex.map { _ in URLQueryItem(name: "subtitleMethod", value: "Encode") },
            URLQueryItem(name: "videoCodec", value: "h264"),
            URLQueryItem(name: "profile", value: "high"),
            URLQueryItem(name: "audioCodec", value: Self.playbackAudioCodecs),
            URLQueryItem(name: "deviceId", value: deviceID),
            URLQueryItem(name: "api_key", value: accessToken)
        ]
        .compactMap { $0 }

        guard let url = components.url else {
            throw MediaConnectorError.unavailable
        }

        let method: JellyfinPlaybackMethod = mediaSource.supportsDirectStream ? .directStream : .transcode
        return (
            MediaPlaybackResource(
                url: url,
                localStartOffsetMilliseconds: offsetMilliseconds,
                descriptionPrefix: method == .transcode ? "Transcoding: H.264 video • AAC audio" : nil
            ),
            method,
            mediaSource.id
        )
    }

    private func directPlayURL(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        playbackInfo: JellyfinPlaybackInfoResponse,
        mediaSource: JellyfinMediaSource
    ) -> URL? {
        guard mediaSource.isDirectPlayable,
              let container = mediaSource.directPlayContainer,
              var components = URLComponents(
                  string: "\(normalize(serverURL: serverURL))/Videos/\(itemID)/stream.\(container)"
              ) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "Static", value: "true"),
            mediaSource.id.map { URLQueryItem(name: "mediaSourceId", value: $0) },
            playbackInfo.playSessionId.map { URLQueryItem(name: "playSessionId", value: $0) },
            URLQueryItem(name: "deviceId", value: deviceID),
            URLQueryItem(name: "api_key", value: accessToken)
        ]
        .compactMap { $0 }
        return components.url
    }

    func reportPlaybackProgress(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        playbackMethod: JellyfinPlaybackMethod,
        mediaSourceID: String?,
        playSessionID: String?,
        time: Int,
        isPaused: Bool
    ) async throws {
        var request = URLRequest(url: try url(serverURL: serverURL, path: "/Sessions/Playing/Progress"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            JellyfinPlaybackProgressBody(
                ItemId: itemID,
                MediaSourceId: mediaSourceID,
                PlaySessionId: playSessionID,
                PositionTicks: max(time, 0) * 10_000,
                IsPaused: isPaused,
                CanSeek: true,
                PlayMethod: playbackMethod.rawValue
            )
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        try await sendVoid(request, priority: .playback)
    }

    func reportPlaybackStopped(
        for itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String,
        mediaSourceID: String?,
        playSessionID: String?,
        time: Int
    ) async throws {
        var request = URLRequest(url: try url(serverURL: serverURL, path: "/Sessions/Playing/Stopped"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            JellyfinPlaybackStopBody(
                ItemId: itemID,
                MediaSourceId: mediaSourceID,
                PlaySessionId: playSessionID,
                PositionTicks: max(time, 0) * 10_000
            )
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        try await sendVoid(request, priority: .playback)

        guard time > 0 else { return }

        let userData = try await itemUserData(
            itemID: itemID,
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID
        )
        try await updateUserData(
            itemID: itemID,
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            body: JellyfinUpdateUserDataBody(
                Played: userData.played,
                PlayCount: userData.playCount,
                PlaybackPositionTicks: max(time, 0) * 10_000,
                LastPlayedDate: ISO8601DateFormatter().string(from: Date()),
                ItemId: itemID
            )
        )
    }

    func markPlayed(
        itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws {
        let userData = try await itemUserData(
            itemID: itemID,
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID
        )
        try await updateUserData(
            itemID: itemID,
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            body:
            JellyfinUpdateUserDataBody(
                Played: true,
                PlayCount: max((userData.playCount ?? 0) + 1, 1),
                PlaybackPositionTicks: 0,
                LastPlayedDate: ISO8601DateFormatter().string(from: Date()),
                ItemId: itemID
            )
        )
    }

    func markUnplayed(
        itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws {
        try await updateUserData(
            itemID: itemID,
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            body: JellyfinUpdateUserDataBody(
                Played: false,
                PlayCount: 0,
                PlaybackPositionTicks: 0,
                LastPlayedDate: ISO8601DateFormatter().string(from: Date()),
                ItemId: itemID
            )
        )
    }

    private func fetchPublicSystemInfo(serverURL: String, accessToken: String) async throws -> JellyfinPublicSystemInfo {
        var request = URLRequest(url: try url(serverURL: serverURL, path: "/System/Info/Public"))
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        return try await send(request)
    }

    private func fetchSessionID(serverURL: String, accessToken: String) async throws -> String? {
        var components = try URLComponents(url: url(serverURL: serverURL, path: "/Sessions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "deviceId", value: deviceID)]

        guard let url = components?.url else {
            return nil
        }

        var request = URLRequest(url: url)
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        let sessions: [JellyfinSessionInfoResponse] = try await send(request)
        return sessions.first?.id
    }

    private func fetchLibraries(serverURL: String, accessToken: String, userID: String) async throws -> [JellyfinLibrary] {
        var components = try URLComponents(url: url(serverURL: serverURL, path: "/UserViews"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "includeHidden", value: "false")
        ]

        guard let url = components?.url else {
            throw MediaConnectorError.unavailable
        }

        var request = URLRequest(url: url)
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        let response: JellyfinItemsResponse = try await send(request)

        var libraries: [JellyfinLibrary] = []

        for view in response.items where supportedCollectionTypes.contains(view.collectionType ?? "") {
            let items = try await fetchPreviewItems(for: view, serverURL: serverURL, accessToken: accessToken, userID: userID)
            libraries.append(
                JellyfinLibrary(
                    id: view.id,
                    title: view.name,
                    collectionType: view.collectionType,
                    items: items
                )
            )
        }

        return libraries
    }

    private func fetchPreviewItems(
        for library: JellyfinItem,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws -> [JellyfinItem] {
        try await fetchItems(
            serverURL: serverURL,
            accessToken: accessToken,
            queryItems: previewQueryItems(for: library, userID: userID)
        ).items
    }

    private func fetchAllItems(
        serverURL: String,
        accessToken: String,
        queryItems: [URLQueryItem],
        pageSize: Int = 500
    ) async throws -> [JellyfinItem] {
        var items: [JellyfinItem] = []
        var startIndex = 0

        while true {
            let page = try await fetchItems(
                serverURL: serverURL,
                accessToken: accessToken,
                queryItems: queryItems + [
                    URLQueryItem(name: "startIndex", value: String(startIndex)),
                    URLQueryItem(name: "limit", value: String(pageSize))
                ]
            )

            items.append(contentsOf: page.items)
            startIndex += page.items.count

            if page.items.isEmpty || items.count >= page.totalRecordCount {
                return items
            }
        }
    }

    private func fetchItems(
        serverURL: String,
        accessToken: String,
        queryItems: [URLQueryItem]
    ) async throws -> JellyfinItemsResponse {
        var components = try URLComponents(url: url(serverURL: serverURL, path: "/Items"), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw MediaConnectorError.unavailable
        }

        var request = URLRequest(url: url)
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        return try await send(request)
    }

    private func itemUserData(
        itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String
    ) async throws -> JellyfinUserData {
        var components = try URLComponents(url: url(serverURL: serverURL, path: "/UserItems/\(itemID)/UserData"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userID)]

        guard let url = components?.url else {
            throw MediaConnectorError.unavailable
        }

        var request = URLRequest(url: url)
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        return try await send(request)
    }

    private func updateUserData(
        itemID: String,
        serverURL: String,
        accessToken: String,
        userID: String,
        body: JellyfinUpdateUserDataBody
    ) async throws {
        var components = try URLComponents(url: url(serverURL: serverURL, path: "/UserItems/\(itemID)/UserData"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userID)]

        guard let url = components?.url else {
            throw MediaConnectorError.unavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeaders(to: &request, accessToken: accessToken)
        try await sendVoid(request)
    }

    private func previewQueryItems(for library: JellyfinItem, userID: String) -> [URLQueryItem] {
        var items = baseItemQueryItems(userID: userID, parentID: library.id)
        items += [
            URLQueryItem(name: "recursive", value: "true"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "sortBy", value: "DateCreated"),
            URLQueryItem(name: "sortOrder", value: "Descending")
        ]

        return items + libraryTypeQueryItems(collectionType: library.collectionType, recursive: true)
    }

    private func libraryQueryItems(for library: LibraryReference, userID: String) -> [URLQueryItem] {
        var items = baseItemQueryItems(userID: userID, parentID: library.id)
        items += [
            URLQueryItem(name: "recursive", value: "true"),
            URLQueryItem(name: "sortBy", value: "SortName"),
            URLQueryItem(name: "sortOrder", value: "Ascending")
        ]

        let collectionType: String
        switch library.defaultItemKind {
        case .movie:
            collectionType = "movies"
        case .series:
            collectionType = "tvshows"
        case .season, .episode, .other:
            collectionType = "other"
        }

        return items + libraryTypeQueryItems(collectionType: collectionType, recursive: true)
    }

    private func baseItemQueryItems(userID: String, parentID: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "parentId", value: parentID),
            URLQueryItem(name: "fields", value: "Overview,DateCreated"),
            URLQueryItem(name: "enableUserData", value: "true"),
            URLQueryItem(name: "enableImages", value: "true"),
            URLQueryItem(name: "enableTotalRecordCount", value: "true")
        ]
    }

    private func libraryTypeQueryItems(collectionType: String?, recursive: Bool) -> [URLQueryItem] {
        switch collectionType {
        case "movies":
            [URLQueryItem(name: "includeItemTypes", value: "Movie")]
        case "tvshows":
            [URLQueryItem(name: "includeItemTypes", value: "Series")]
        default:
            [
                URLQueryItem(name: "mediaTypes", value: "Video"),
                recursive ? URLQueryItem(name: "filters", value: "IsNotFolder") : nil
            ]
            .compactMap { $0 }
        }
    }

    private func applyAuthorizationHeaders(to request: inout URLRequest, accessToken: String? = nil) {
        let authValue: String
        if let accessToken {
            authValue = "MediaBrowser Token=\"\(accessToken)\", Client=\"Freya Player\", Device=\"\(PlatformMetadata.deviceName)\", DeviceId=\"\(deviceID)\", Version=\"\(clientVersion)\""
        } else {
            authValue = "MediaBrowser Client=\"Freya Player\", Device=\"\(PlatformMetadata.deviceName)\", DeviceId=\"\(deviceID)\", Version=\"\(clientVersion)\""
        }

        request.setValue(authValue, forHTTPHeaderField: "Authorization")
    }

    private func normalize(serverURL: String, scheme: String = "https") -> String {
        let trimmed = serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return trimmed }

        let rawURL = hasScheme(trimmed) ? trimmed : "\(scheme)://\(trimmed)"
        guard var components = URLComponents(string: rawURL) else {
            return rawURL
        }

        if components.port == nil,
           components.path.isEmpty || components.path == "/" {
            components.port = 8096
        }

        if components.path == "/" {
            components.path = ""
        }

        return components.url?.absoluteString ?? rawURL
    }

    private func hasScheme(_ serverURL: String) -> Bool {
        serverURL.contains("://")
    }

    private func performAuthentication(
        serverURL: String,
        username: String,
        password: String
    ) async throws -> (JellyfinAuthenticationResult, String) {
        var request = URLRequest(url: try url(serverURL: serverURL, path: "/Users/AuthenticateByName"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode([
            "Username": username,
            "Pw": password
        ])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeaders(to: &request)
        return try await (send(request), serverURL)
    }

    private func url(serverURL: String, path: String) throws -> URL {
        guard let url = URL(string: normalize(serverURL: serverURL) + path) else {
            throw JellyfinError.invalidURL
        }

        return url
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        priority: RequestScheduler.Priority = .normal
    ) async throws -> Response {
        let (data, response) = try await session.gatedData(for: request, priority: priority)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw JellyfinError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func sendVoid(
        _ request: URLRequest,
        priority: RequestScheduler.Priority = .normal
    ) async throws {
        let (_, response) = try await session.gatedData(for: request, priority: priority)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw JellyfinError.requestFailed(httpResponse.statusCode)
        }
    }

    private var clientVersion: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func loadDeviceID(defaults: any DefaultsStore) -> String {
        let key = "jellyfin.client.identifier"

        if let existing = defaults.string(forKey: key) {
            return existing
        }

        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: key)
        return identifier
    }

    private let supportedCollectionTypes: Set<String> = ["movies", "tvshows", "homevideos", "folders"]

    private static var playbackAudioCodecs: String {
        PlatformMetadata.prefersAACPlaybackAudio ? "aac" : "aac,ac3,eac3"
    }
}

private extension MediaPlaybackQuality {
    var jellyfinMaxWidth: String? {
        switch self {
        case .automatic: nil
        case .p1080: "1920"
        case .p720: "1280"
        case .p480: "854"
        case .p240: "426"
        }
    }
}

private enum JellyfinError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That Jellyfin server URL doesn't look valid."
        case .invalidResponse:
            return "Jellyfin returned a response Freya couldn't read."
        case .requestFailed(401), .requestFailed(403):
            return "Jellyfin rejected the sign-in. Check the username, password, and user permissions."
        case .requestFailed(404):
            return "Freya reached that address, but it doesn't look like a Jellyfin server."
        case .requestFailed(let statusCode):
            return "Jellyfin returned HTTP \(statusCode). Please try again."
        }
    }
}

private struct JellyfinSessionInfoResponse: Decodable {
    let id: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
    }
}

enum JellyfinPlaybackMethod: String {
    case transcode = "Transcode"
    case directStream = "DirectStream"
    case directPlay = "DirectPlay"
}

private struct JellyfinPlaybackInfoBody: Encodable {
    let UserId: String
    let MaxStreamingBitrate: Int?
    let AudioStreamIndex: Int?
    let SubtitleStreamIndex: Int?
    let EnableDirectPlay: Bool
    let EnableDirectStream: Bool
    let EnableTranscoding: Bool
}

private struct JellyfinPlaybackProgressBody: Encodable {
    let ItemId: String
    let MediaSourceId: String?
    let PlaySessionId: String?
    let PositionTicks: Int
    let IsPaused: Bool
    let CanSeek: Bool
    let PlayMethod: String
}

private struct JellyfinPlaybackStopBody: Encodable {
    let ItemId: String
    let MediaSourceId: String?
    let PlaySessionId: String?
    let PositionTicks: Int
}

private struct JellyfinUpdateUserDataBody: Encodable {
    let Played: Bool?
    let PlayCount: Int?
    let PlaybackPositionTicks: Int
    let LastPlayedDate: String
    let ItemId: String
}

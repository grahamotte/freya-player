import Foundation

final class PlexClient {
    private let session: URLSession
    private let clientIdentifier: String

    init(session: URLSession = .shared) {
        self.session = session
        self.clientIdentifier = Self.loadClientIdentifier()
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
                        libraries: sections
                    )
                } catch {
                    continue
                }
            }
        }

        throw PlexError.noReachableServer
    }

    func playbackURL(for ratingKey: String, connection: PlexConnectionSummary) async throws -> URL {
        let metadata = try await fetchPlaybackMetadata(
            ratingKey: ratingKey,
            baseURL: connection.serverURL,
            token: connection.serverToken
        )

        if let url = directPlayURL(from: metadata, connection: connection) {
            return url
        }

        guard let url = transcodedMovieStreamURL(for: ratingKey, connection: connection) else {
            throw PlexError.invalidURL
        }

        return url
    }

    private func transcodedMovieStreamURL(for ratingKey: String, connection: PlexConnectionSummary) -> URL? {
        guard var components = URLComponents(
            string: "\(connection.serverURL)/video/:/transcode/universal/start.m3u8"
        ) else {
            return nil
        }

        let sessionID = UUID().uuidString

        components.queryItems = [
            URLQueryItem(name: "path", value: "/library/metadata/\(ratingKey)"),
            URLQueryItem(name: "mediaIndex", value: "0"),
            URLQueryItem(name: "partIndex", value: "0"),
            URLQueryItem(name: "protocol", value: "hls"),
            URLQueryItem(name: "directPlay", value: "1"),
            URLQueryItem(name: "directStream", value: "1"),
            URLQueryItem(name: "directStreamAudio", value: "1"),
            URLQueryItem(name: "subtitles", value: "auto"),
            URLQueryItem(name: "transcodeSessionId", value: sessionID),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: clientIdentifier),
            URLQueryItem(name: "X-Plex-Product", value: "Freya Player"),
            URLQueryItem(name: "X-Plex-Version", value: clientVersion),
            URLQueryItem(name: "X-Plex-Platform", value: "tvOS"),
            URLQueryItem(name: "X-Plex-Device", value: "Apple TV"),
            URLQueryItem(name: "X-Plex-Device-Name", value: "Freya Player")
        ]

        return components.url
    }

    private func fetchPlaybackMetadata(
        ratingKey: String,
        baseURL: String,
        token: String
    ) async throws -> PlexPlaybackMetadata {
        guard var components = URLComponents(string: "\(baseURL)/library/metadata/\(ratingKey)") else {
            throw PlexError.invalidURL
        }

        components.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: token)

        let response: PlexMetadataContainer<PlexPlaybackMetadata> = try await send(request)

        guard let metadata = response.mediaContainer.metadata?.first else {
            throw PlexError.invalidResponse
        }

        return metadata
    }

    private func directPlayURL(from metadata: PlexPlaybackMetadata, connection: PlexConnectionSummary) -> URL? {
        guard let partKey = metadata.media?.first(where: \.isDirectPlayable)?.parts?.first?.key,
              var components = URLComponents(string: "\(connection.serverURL)\(partKey)") else {
            return nil
        }

        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "download", value: "0"),
            URLQueryItem(name: "X-Plex-Token", value: connection.serverToken)
        ]

        return components.url
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
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw PlexError.invalidURL
        }

        components.queryItems = extraQueryItems + [
            URLQueryItem(name: "X-Plex-Container-Start", value: "0"),
            URLQueryItem(name: "X-Plex-Container-Size", value: "20"),
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]

        var request = URLRequest(url: components.url!)
        applyPlexHeaders(to: &request, token: token)

        let response: PlexMetadataContainer<PlexMediaItem> = try await send(request)
        return response.mediaContainer.metadata ?? []
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw PlexError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func applyPlexHeaders(to request: inout URLRequest, token: String? = nil) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("Freya Player", forHTTPHeaderField: "X-Plex-Product")
        request.setValue(clientVersion, forHTTPHeaderField: "X-Plex-Version")
        request.setValue("tvOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue("Apple TV", forHTTPHeaderField: "X-Plex-Device")
        request.setValue("Freya Player", forHTTPHeaderField: "X-Plex-Device-Name")

        if let token {
            request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func loadClientIdentifier() -> String {
        let defaults = UserDefaults.standard
        let key = "plex.client.identifier"

        if let existing = defaults.string(forKey: key) {
            return existing
        }

        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: key)
        return identifier
    }
}

private enum PlexError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case noReachableServer
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

        private enum CodingKeys: String, CodingKey {
            case metadata = "Metadata"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private struct PlexPlaybackMetadata: Decodable {
    let media: [Media]?

    private enum CodingKeys: String, CodingKey {
        case media = "Media"
    }

    struct Media: Decodable {
        let container: String?
        let videoCodec: String?
        let audioCodec: String?
        let parts: [Part]?

        var isDirectPlayable: Bool {
            guard let parts, !parts.isEmpty else { return false }
            return Self.supportedContainers.contains(container?.lowercased() ?? "")
                && Self.supportedVideoCodecs.contains(videoCodec?.lowercased() ?? "")
                && Self.supportedAudioCodecs.contains(audioCodec?.lowercased() ?? "")
        }

        private static let supportedContainers = ["mp4", "m4v", "mov"]
        private static let supportedVideoCodecs = ["h264", "avc", "avc1", "hevc", "h265", "hvc1"]
        private static let supportedAudioCodecs = ["aac", "ac3", "eac3", "mp3"]

        private enum CodingKeys: String, CodingKey {
            case container
            case videoCodec
            case audioCodec
            case parts = "Part"
        }
    }

    struct Part: Decodable {
        let key: String
    }
}

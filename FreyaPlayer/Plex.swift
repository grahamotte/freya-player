import Foundation
import Security

struct PlexConnectionSummary {
    let serverID: String
    let serverName: String
    let serverURL: String
    let libraries: [PlexLibrary]
}

struct PlexLibrary: Decodable, Identifiable {
    let key: String
    let title: String
    let type: String
    var id: String { key }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        key = try container.decodeLossyString(forKey: .key)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case type
    }
}

struct PlexPin: Decodable {
    let id: Int
    let code: String
    let authToken: String?
    let expiresIn: Int?
}

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
        let servers = try await fetchServers(userToken: userToken)
        let orderedServers = orderServers(servers, preferredServerID: preferredServerID)

        for server in orderedServers {
            let token = server.accessToken ?? userToken

            for connection in orderConnections(server.connections ?? []) {
                do {
                    let libraries = try await fetchLibraries(baseURL: connection.uri, token: token)
                    return PlexConnectionSummary(
                        serverID: server.clientIdentifier,
                        serverName: server.name,
                        serverURL: connection.uri,
                        libraries: libraries
                    )
                } catch {
                    continue
                }
            }
        }

        throw PlexError.noReachableServer
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

        let response: PlexContainer<PlexLibrary> = try await send(request)
        return response.mediaContainer.directory ?? []
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
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0", forHTTPHeaderField: "X-Plex-Version")
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

final class PlexSessionStore {
    private let defaults = UserDefaults.standard
    private let tokenKey = "plex.user.token"
    private let serverKey = "plex.server.identifier"

    var userToken: String? {
        get { KeychainStore.value(for: tokenKey) }
        set {
            if let newValue {
                KeychainStore.setValue(newValue, for: tokenKey)
            } else {
                KeychainStore.removeValue(for: tokenKey)
            }
        }
    }

    var serverIdentifier: String? {
        get { defaults.string(forKey: serverKey) }
        set { defaults.set(newValue, forKey: serverKey) }
    }

    func clear() {
        userToken = nil
        defaults.removeObject(forKey: serverKey)
    }
}

private enum PlexError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case noReachableServer
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

private struct PlexContainer<Item: Decodable>: Decodable {
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

private enum KeychainStore {
    private static let service = "ottecode.FreyaPlayer"

    static func value(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func setValue(_ value: String, for key: String) {
        removeValue(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }

        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }

        throw DecodingError.typeMismatch(
            String.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a String or Int.")
        )
    }
}

import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlexConnectorTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.reset()
    }

    func testRefreshConnectionPersistsServerIdentifier() async throws {
        let defaults = makeDefaults(testCase: self)
        let secureStore = TestSecureStore()
        let store = PlexSessionStore(
            defaults: defaults,
            loadSecureValue: secureStore.value(for:),
            saveSecureValue: secureStore.setValue(_:for:),
            removeSecureValue: secureStore.removeValue(for:)
        )
        store.userToken = "user-token"
        let connector = PlexConnector(
            client: PlexClient(session: makeTestSession(), defaults: defaults),
            store: store
        )

        TestURLProtocol.handler = { request in
            switch (request.url?.host, request.url?.path) {
            case ("plex.tv", "/api/v2/user"):
                return jsonResponse(["friendlyName": "Graham"])
            case ("plex.tv", "/api/v2/resources"):
                return jsonResponse([[
                    "name": "Preferred",
                    "clientIdentifier": "preferred",
                    "provides": "server",
                    "accessToken": "server-token",
                    "owned": true,
                    "connections": [["protocol": "https", "uri": "https://preferred.local", "local": true, "relay": false]]
                ]])
            case ("preferred.local", "/library/sections"):
                return jsonResponse(["MediaContainer": ["Directory": []]])
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return jsonResponse([:])
            }
        }

        let server = try await connector.refreshConnection()

        XCTAssertEqual(server.serverID, "preferred")
        XCTAssertEqual(server.providerID, .plex)
        XCTAssertEqual(store.serverIdentifier, "preferred")
    }
}

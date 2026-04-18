import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class JellyfinConnectorTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.reset()
    }

    func testConnectPersistsCredentialsAndTracksPlaybackContext() async throws {
        let defaults = makeDefaults(testCase: self)
        let secureStore = TestSecureStore()
        let store = JellyfinSessionStore(
            defaults: defaults,
            loadSecureValue: secureStore.value(for:),
            saveSecureValue: secureStore.setValue(_:for:),
            removeSecureValue: secureStore.removeValue(for:)
        )
        let connector = JellyfinConnector(
            client: JellyfinClient(session: makeTestSession(), defaults: defaults),
            store: store
        )

        TestURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/Users/AuthenticateByName"):
                return jsonResponse(["User": ["Id": "user-id", "Name": "Graham"], "AccessToken": "token"])
            case (_, "/System/Info/Public"):
                return jsonResponse(["Id": "server", "ServerName": "Jellyfin"])
            case (_, "/UserViews"):
                return jsonResponse(["Items": [], "TotalRecordCount": 0])
            case (_, "/Sessions"):
                return jsonResponse([["Id": "session"]])
            case ("POST", "/Items/item/PlaybackInfo"):
                return jsonResponse([
                    "PlaySessionId": "play",
                    "MediaSources": [[
                        "Id": "source",
                        "SupportsDirectPlay": false,
                        "SupportsDirectStream": false,
                        "SupportsTranscoding": true,
                        "TranscodingUrl": "/Videos/item/master.m3u8"
                    ]]
                ])
            case ("POST", "/Sessions/Playing/Progress"):
                return StubbedHTTPResponse(body: Data())
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                return StubbedHTTPResponse(body: Data())
            }
        }

        _ = try await connector.connect(serverURL: "https://jf.local", username: "user", password: "pw")
        _ = try await connector.playbackURL(for: MediaPlaybackID(providerID: .jellyfin, itemID: "item"), selection: nil)
        try await connector.reportPlaybackTimeline(
            for: MediaPlaybackID(providerID: .jellyfin, itemID: "item"),
            state: .playing,
            time: 2_000,
            duration: nil,
            sessionID: "ignored"
        )

        let progressRequest = try XCTUnwrap(TestURLProtocol.requests.first(where: { $0.url?.path == "/Sessions/Playing/Progress" }))

        XCTAssertEqual(store.serverURL, "https://jf.local")
        XCTAssertEqual(store.userID, "user-id")
        XCTAssertEqual(store.userName, "Graham")
        XCTAssertEqual(store.accessToken, "token")
        XCTAssertEqual(jsonObjectBody(for: progressRequest)["PlayMethod"] as? String, "Transcode")
    }
}

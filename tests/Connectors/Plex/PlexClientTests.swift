import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlexClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.reset()
    }

    func testCreatePinPostsHeaders() async throws {
        let defaults = makeDefaults(testCase: self)
        defaults.set("client-id", forKey: "plex.client.identifier")
        let client = PlexClient(session: makeTestSession(), defaults: defaults)

        TestURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://plex.tv/api/v2/pins")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Client-Identifier"), "client-id")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Product"), "Freya Player")
            return jsonResponse(["id": 1, "code": "ABCD", "authToken": NSNull(), "expiresIn": 900])
        }

        let pin = try await client.createPin()
        XCTAssertEqual(pin.id, 1)
        XCTAssertEqual(pin.code, "ABCD")
    }

    func testConnectChoosesPreferredServerAndLoadsLibraries() async throws {
        let client = PlexClient(session: makeTestSession(), defaults: makeDefaults(testCase: self))

        TestURLProtocol.handler = { request in
            switch (request.url?.host, request.url?.path) {
            case ("plex.tv", "/api/v2/user"):
                return jsonResponse(["friendlyName": "Graham"])

            case ("plex.tv", "/api/v2/resources"):
                return jsonResponse([
                    [
                        "name": "Backup",
                        "clientIdentifier": "backup",
                        "provides": "server",
                        "owned": false,
                        "connections": [["protocol": "https", "uri": "https://backup.local", "local": false, "relay": false]]
                    ],
                    [
                        "name": "Preferred",
                        "clientIdentifier": "preferred",
                        "provides": "server",
                        "accessToken": "server-token",
                        "owned": true,
                        "connections": [["protocol": "https", "uri": "https://preferred.local", "local": true, "relay": false]]
                    ]
                ])

            case ("preferred.local", "/library/sections"):
                return jsonResponse([
                    "MediaContainer": [
                        "Directory": [
                            ["key": 1, "title": "Movies", "type": "movie", "agent": "tv.plex.agents.movie"]
                        ]
                    ]
                ])

            case ("preferred.local", "/library/sections/1/recentlyAdded"):
                return jsonResponse([
                    "MediaContainer": [
                        "Metadata": [
                            ["ratingKey": "movie-1", "type": "movie", "title": "Movie", "thumb": "/thumb.jpg"]
                        ],
                        "totalSize": 1
                    ]
                ])

            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return jsonResponse([:])
            }
        }

        let summary = try await client.connect(userToken: "user-token", preferredServerID: "preferred")

        XCTAssertEqual(summary.serverID, "preferred")
        XCTAssertEqual(summary.serverToken, "server-token")
        XCTAssertEqual(summary.accountName, "Graham")
        XCTAssertEqual(summary.libraries.map(\.title), ["Movies"])
        XCTAssertEqual(summary.libraries.first?.items.map(\.title), ["Movie"])
    }

    func testPlaybackURLReturnsDirectPlayURLWhenSupported() async throws {
        let client = PlexClient(session: makeTestSession(), defaults: makeDefaults(testCase: self))
        let connection = PlexConnectionSummary(
            serverID: "server",
            serverName: "Server",
            serverURL: "https://plex.local",
            serverToken: "token",
            accountName: "Account",
            libraries: []
        )

        TestURLProtocol.handler = { _ in
            jsonResponse([
                "MediaContainer": [
                    "Metadata": [[
                        "Media": [[
                            "container": "mp4",
                            "videoCodec": "h264",
                            "audioCodec": "aac",
                            "Part": [[
                                "id": 55,
                                "key": "/library/parts/movie.mp4",
                                "Stream": [["id": 1, "streamType": 2, "selected": true, "displayTitle": "English"]]
                            ]]
                        ]]
                    ]]
                ]
            ])
        }

        let url = try await client.playbackURL(for: "movie", connection: connection)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        XCTAssertEqual(url.host, "plex.local")
        XCTAssertEqual(url.path, "/library/parts/movie.mp4")
        XCTAssertEqual(query?.first(where: { $0.name == "X-Plex-Token" })?.value, "token")
        XCTAssertEqual(TestURLProtocol.requests.count, 1)
    }

    func testPlaybackURLAppliesSelectionBeforeTranscoding() async throws {
        let defaults = makeDefaults(testCase: self)
        defaults.set("client-id", forKey: "plex.client.identifier")
        let client = PlexClient(session: makeTestSession(), defaults: defaults)
        let connection = PlexConnectionSummary(
            serverID: "server",
            serverName: "Server",
            serverURL: "https://plex.local",
            serverToken: "token",
            accountName: "Account",
            libraries: []
        )

        TestURLProtocol.handler = { request in
            switch request.url?.path {
            case "/library/metadata/movie":
                return jsonResponse([
                    "MediaContainer": [
                        "Metadata": [[
                            "Media": [[
                                "container": "mkv",
                                "videoCodec": "h264",
                                "audioCodec": "aac",
                                "Part": [[
                                    "id": 55,
                                    "key": "/library/parts/movie.mkv",
                                    "Stream": [
                                        ["id": 101, "streamType": 2, "selected": true, "displayTitle": "English"],
                                        ["id": 102, "streamType": 2, "displayTitle": "Spanish"],
                                        ["id": 201, "streamType": 3, "displayTitle": "English CC"]
                                    ]
                                ]]
                            ]]
                        ]]
                    ]
                ])

            case "/library/parts/55":
                XCTAssertEqual(request.httpMethod, "PUT")
                let query = queryItems(for: request)
                XCTAssertEqual(query["audioStreamID"], "102")
                XCTAssertEqual(query["subtitleStreamID"], "201")
                return StubbedHTTPResponse(body: Data())

            case "/video/:/transcode/universal/decision":
                return jsonResponse(["MediaContainer": [:]])

            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return jsonResponse([:])
            }
        }

        let url = try await client.playbackURL(
            for: "movie",
            connection: connection,
            selection: MediaPlaybackSelection(audioID: "102", subtitleID: "201")
        )

        XCTAssertEqual(TestURLProtocol.requests.count, 3)
        XCTAssertEqual(url.path, "/video/:/transcode/universal/start.m3u8")
        XCTAssertEqual(queryItems(for: TestURLProtocol.requests[2])["X-Plex-Client-Identifier"], "client-id")
    }

    func testTimelineAndScrobbleRequestsUseExpectedMethods() async throws {
        let client = PlexClient(session: makeTestSession(), defaults: makeDefaults(testCase: self))
        let connection = PlexConnectionSummary(
            serverID: "server",
            serverName: "Server",
            serverURL: "https://plex.local",
            serverToken: "token",
            accountName: "Account",
            libraries: []
        )

        TestURLProtocol.handler = { _ in
            StubbedHTTPResponse(body: Data())
        }

        try await client.reportTimeline(for: "movie", connection: connection, state: .playing, time: 2_000, duration: 5_000, sessionID: "session")
        try await client.scrobble(for: "movie", connection: connection)
        try await client.unscrobble(for: "movie", connection: connection)

        XCTAssertEqual(TestURLProtocol.requests.map(\.httpMethod), ["POST", "PUT", "PUT"])
        XCTAssertEqual(TestURLProtocol.requests[0].url?.path, "/:/timeline")
        XCTAssertEqual(queryItems(for: TestURLProtocol.requests[0])["state"], "playing")
        XCTAssertEqual(TestURLProtocol.requests[1].url?.path, "/:/scrobble")
        XCTAssertEqual(TestURLProtocol.requests[2].url?.path, "/:/unscrobble")
    }
}

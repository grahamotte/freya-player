import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class JellyfinClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.reset()
    }

    func testAuthenticateNormalizesServerURLAndSendsAuthorizationHeader() async throws {
        let defaults = makeDefaults(testCase: self)
        defaults.set("device-id", forKey: "jellyfin.client.identifier")
        let client = JellyfinClient(session: makeTestSession(), defaults: defaults)

        TestURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://jf.local/Users/AuthenticateByName")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("DeviceId=\"device-id\"") == true)
            return jsonResponse([
                "User": ["Id": "user-id", "Name": "Graham"],
                "AccessToken": "token",
                "ServerId": "server"
            ])
        }

        let result = try await client.authenticate(serverURL: " https://jf.local/ ", username: "user", password: "pw")
        XCTAssertEqual(result.user.id, "user-id")
        XCTAssertEqual(result.accessToken, "token")
    }

    func testConnectionLoadsLibrariesAndSession() async throws {
        let defaults = makeDefaults(testCase: self)
        defaults.set("device-id", forKey: "jellyfin.client.identifier")
        let client = JellyfinClient(session: makeTestSession(), defaults: defaults)

        TestURLProtocol.handler = { request in
            switch request.url?.path {
            case "/System/Info/Public":
                return jsonResponse(["Id": "server", "ServerName": "Jellyfin"])

            case "/UserViews":
                return jsonResponse([
                    "Items": [
                        ["Id": "movies", "Name": "Movies", "CollectionType": "movies"],
                        ["Id": "books", "Name": "Books", "CollectionType": "books"]
                    ],
                    "TotalRecordCount": 2
                ])

            case "/Items":
                let query = queryItems(for: request)
                if query["parentId"] == "movies" {
                    return jsonResponse([
                        "Items": [
                            ["Id": "movie-1", "Name": "Movie", "Type": "Movie", "ImageTags": ["Primary": "poster"]]
                        ],
                        "TotalRecordCount": 1
                    ])
                }
                XCTFail("Unexpected item request: \(request.url?.absoluteString ?? "nil")")
                return jsonResponse(["Items": [], "TotalRecordCount": 0])

            case "/Sessions":
                return jsonResponse([["Id": "session-id"]])

            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return jsonResponse([:])
            }
        }

        let summary = try await client.connection(
            serverURL: "https://jf.local/",
            accessToken: "token",
            userID: "user-id",
            fallbackUserName: "Graham"
        )

        XCTAssertEqual(summary.serverID, "server")
        XCTAssertEqual(summary.serverURL, "https://jf.local")
        XCTAssertEqual(summary.sessionID, "session-id")
        XCTAssertEqual(summary.libraries.map(\.title), ["Movies"])
        XCTAssertEqual(summary.libraries.first?.items.map(\.name), ["Movie"])
    }

    func testPlaybackURLUsesTranscodingURLWhenAvailable() async throws {
        let client = JellyfinClient(session: makeTestSession(), defaults: makeDefaults(testCase: self))
        let playbackInfo = JellyfinPlaybackInfoResponse(
            playSessionId: "play",
            mediaSources: [
                JellyfinMediaSource(
                    id: "source",
                    container: nil,
                    supportsDirectPlay: false,
                    supportsDirectStream: false,
                    supportsTranscoding: true,
                    transcodingURL: "/Videos/123/master.m3u8?static=true",
                    mediaStreams: nil,
                    defaultAudioStreamIndex: nil,
                    defaultSubtitleStreamIndex: nil
                )
            ]
        )

        let (url, method, mediaSourceID) = try client.playbackURL(
            for: "123",
            serverURL: "https://jf.local",
            accessToken: "token",
            playbackInfo: playbackInfo,
            selection: nil
        )

        XCTAssertEqual(url.absoluteString, "https://jf.local/Videos/123/master.m3u8?static=true&api_key=token")
        XCTAssertEqual(method, .transcode)
        XCTAssertEqual(mediaSourceID, "source")
    }

    func testPlaybackURLBuildsMasterPlaylistQuery() async throws {
        let defaults = makeDefaults(testCase: self)
        defaults.set("device-id", forKey: "jellyfin.client.identifier")
        let client = JellyfinClient(session: makeTestSession(), defaults: defaults)
        let playbackInfo = JellyfinPlaybackInfoResponse(
            playSessionId: "play",
            mediaSources: [
                JellyfinMediaSource(
                    id: "source",
                    container: "mp4",
                    supportsDirectPlay: true,
                    supportsDirectStream: true,
                    supportsTranscoding: true,
                    transcodingURL: nil,
                    mediaStreams: nil,
                    defaultAudioStreamIndex: 1,
                    defaultSubtitleStreamIndex: 2
                )
            ]
        )

        let (url, method, mediaSourceID) = try client.playbackURL(
            for: "123",
            serverURL: "https://jf.local",
            accessToken: "token",
            playbackInfo: playbackInfo,
            selection: MediaPlaybackSelection(audioID: "4", subtitleID: "5")
        )
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        XCTAssertEqual(url.path, "/Videos/123/master.m3u8")
        XCTAssertEqual(query.first(where: { $0.name == "audioStreamIndex" })?.value, "4")
        XCTAssertEqual(query.first(where: { $0.name == "subtitleStreamIndex" })?.value, "5")
        XCTAssertEqual(query.first(where: { $0.name == "deviceId" })?.value, "device-id")
        XCTAssertEqual(method, .directStream)
        XCTAssertEqual(mediaSourceID, "source")
    }

    func testPlaybackProgressStopAndUserDataUpdatesUseExpectedBodies() async throws {
        let client = JellyfinClient(session: makeTestSession(), defaults: makeDefaults(testCase: self))

        TestURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/Sessions/Playing/Progress"),
                ("POST", "/Sessions/Playing/Stopped"),
                ("POST", "/UserItems/123/UserData"):
                return StubbedHTTPResponse(body: Data())

            case ("GET", "/UserItems/123/UserData"):
                return jsonResponse(["Played": false, "PlayCount": 2, "PlaybackPositionTicks": 0])

            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                return StubbedHTTPResponse(body: Data())
            }
        }

        try await client.reportPlaybackProgress(
            for: "123",
            serverURL: "https://jf.local",
            accessToken: "token",
            playbackMethod: .directPlay,
            mediaSourceID: "source",
            time: 2_000,
            isPaused: true
        )
        try await client.reportPlaybackStopped(
            for: "123",
            serverURL: "https://jf.local",
            accessToken: "token",
            userID: "user",
            mediaSourceID: "source",
            time: 3_000
        )
        try await client.markPlayed(itemID: "123", serverURL: "https://jf.local", accessToken: "token", userID: "user")
        try await client.markUnplayed(itemID: "123", serverURL: "https://jf.local", accessToken: "token", userID: "user")

        let progressRequest = try XCTUnwrap(TestURLProtocol.requests.first(where: { $0.url?.path == "/Sessions/Playing/Progress" }))
        let stopRequest = try XCTUnwrap(TestURLProtocol.requests.first(where: { $0.url?.path == "/Sessions/Playing/Stopped" }))
        let updateRequests = TestURLProtocol.requests.filter { $0.url?.path == "/UserItems/123/UserData" && $0.httpMethod == "POST" }

        XCTAssertEqual(TestURLProtocol.requests.count, 7)
        XCTAssertEqual(jsonObjectBody(for: progressRequest)["PlayMethod"] as? String, "DirectPlay")
        XCTAssertEqual(jsonObjectBody(for: stopRequest)["PositionTicks"] as? Int, 30_000_000)
        XCTAssertEqual(jsonObjectBody(for: updateRequests[1])["Played"] as? Bool, true)
        XCTAssertEqual(jsonObjectBody(for: updateRequests[2])["PlayCount"] as? Int, 0)
    }
}

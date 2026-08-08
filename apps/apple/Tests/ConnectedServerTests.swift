import XCTest
@testable import FreyaPlayerCore

final class ConnectedServerTests: XCTestCase {
    func testReplacingAndClearingLibrariesPreservesServer() {
        let shelf = makeLibraryShelf(items: [makeMediaItem()])
        let server = ConnectedServer(
            providerID: .plex,
            serverID: "server",
            serverName: "Home",
            serverURL: "https://example.com",
            accountName: "Account",
            libraries: [shelf]
        )

        XCTAssertEqual(server.id, "plex:server")
        XCTAssertTrue(server.clearingCachedItems().libraries[0].items.isEmpty)
        XCTAssertEqual(server.settingLibraries([]).serverName, "Home")
    }
}

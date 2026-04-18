import Foundation
import XCTest

#if os(tvOS)
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#else
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif
#endif

@MainActor
final class TestSecureStore {
    private(set) var values: [String: String] = [:]

    func value(for key: String) -> String? {
        values[key]
    }

    func setValue(_ value: String, for key: String) {
        values[key] = value
    }

    func removeValue(for key: String) {
        values.removeValue(forKey: key)
    }
}

enum TestError: Error {
    case example
}

@MainActor
final class TestDefaultsStore: DefaultsStore {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func stringArray(forKey defaultName: String) -> [String]? {
        values[defaultName] as? [String]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    func removeAll() {
        values.removeAll()
    }
}

@MainActor
func makeDefaults(testCase: XCTestCase, name: String = UUID().uuidString) -> TestDefaultsStore {
    let defaults = TestDefaultsStore()
    _ = name
    _ = testCase
    return defaults
}

func makeArtwork(seed: String = "1") -> MediaArtworkSet {
    MediaArtworkSet(
        posterURL: URL(string: "https://example.com/poster-\(seed).jpg"),
        landscapeURL: URL(string: "https://example.com/landscape-\(seed).jpg"),
        backdropURL: URL(string: "https://example.com/backdrop-\(seed).jpg")
    )
}

func makeLibraryReference(
    providerID: MediaProviderID = .jellyfin,
    serverID: String = "server",
    id: String = "library",
    title: String = "Library",
    itemTitle: String = "movie",
    artworkStyle: MediaArtworkStyle = .poster,
    defaultItemKind: MediaItemKind = .movie
) -> LibraryReference {
    LibraryReference(
        providerID: providerID,
        serverID: serverID,
        id: id,
        title: title,
        itemTitle: itemTitle,
        artworkStyle: artworkStyle,
        defaultItemKind: defaultItemKind
    )
}

func makeMediaItem(
    providerID: MediaProviderID = .jellyfin,
    serverID: String = "server",
    id: String = UUID().uuidString,
    title: String = "Item",
    kind: MediaItemKind = .movie,
    synopsis: String = "Synopsis",
    addedAt: Int? = 100,
    year: Int? = 2024,
    durationMilliseconds: Int? = 7_200_000,
    contentRating: String? = "PG",
    isWatched: Bool = false,
    progress: Double? = nil,
    resumeOffsetMilliseconds: Int? = nil,
    artwork: MediaArtworkSet = makeArtwork()
) -> MediaItem {
    MediaItem(
        providerID: providerID,
        serverID: serverID,
        id: id,
        title: title,
        kind: kind,
        synopsis: synopsis,
        addedAt: addedAt,
        year: year,
        durationMilliseconds: durationMilliseconds,
        contentRating: contentRating,
        isWatched: isWatched,
        progress: progress,
        resumeOffsetMilliseconds: resumeOffsetMilliseconds,
        artwork: artwork
    )
}

func makeLibraryShelf(
    id: String = "library",
    title: String = "Library",
    reference: LibraryReference = makeLibraryReference(),
    items: [MediaItem] = [makeMediaItem()],
    isHidden: Bool = false
) -> LibraryShelf {
    LibraryShelf(id: id, title: title, reference: reference, items: items, isHidden: isHidden)
}

func makeConnectedServer(
    providerID: MediaProviderID = .jellyfin,
    serverID: String = "server",
    serverName: String = "Server",
    accountName: String = "Account",
    libraries: [LibraryShelf] = [makeLibraryShelf()]
) -> ConnectedServer {
    ConnectedServer(
        providerID: providerID,
        serverID: serverID,
        serverName: serverName,
        accountName: accountName,
        libraries: libraries
    )
}

@MainActor
func waitUntil(
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return
        }

        try? await Task.sleep(for: .milliseconds(10))
    }

    XCTFail("Timed out waiting for condition.", file: file, line: line)
}

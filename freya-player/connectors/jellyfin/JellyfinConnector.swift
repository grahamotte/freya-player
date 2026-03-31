import Foundation

final class JellyfinConnector: MediaConnector {
    let providerID: MediaProviderID = .jellyfin

    func restoreConnection() async throws -> ConnectedServer? {
        nil
    }

    func refreshConnection() async throws -> ConnectedServer {
        throw MediaConnectorError.unavailable
    }

    func disconnect() {}

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        throw MediaConnectorError.unavailable
    }

    func loadChildren(for item: MediaItem) async throws -> [MediaItem] {
        throw MediaConnectorError.unavailable
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        throw MediaConnectorError.unavailable
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection?) async throws -> URL {
        throw MediaConnectorError.unavailable
    }

    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws {
        throw MediaConnectorError.unavailable
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async throws {
        throw MediaConnectorError.unavailable
    }
}

protocol MediaConnector: AnyObject {
    var providerID: MediaProviderID { get }

    func restoreConnection() async throws -> ConnectedServer?
    func refreshConnection() async throws -> ConnectedServer
    func disconnect()

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem]
    func loadItem(_ item: MediaItem) async throws -> MediaItem
    func loadChildren(for item: MediaItem) async throws -> [MediaItem]

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions?
    func playbackURL(
        for id: MediaPlaybackID,
        selection: MediaPlaybackSelection?,
        sessionID: String,
        offsetMilliseconds: Int?
    ) async throws -> MediaPlaybackResource
    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async throws
    func stopPlaybackSession(_ sessionID: String) async
    func markPlaybackCompleted(for id: MediaPlaybackID) async throws
    func setWatchStatus(for id: MediaPlaybackID, isWatched: Bool) async throws
}

extension MediaConnector {
    func stopPlaybackSession(_ sessionID: String) async {}
}

enum MediaConnectorError: Error {
    case unavailable
}

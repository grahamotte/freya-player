import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private let mediaSessionStore: MediaSessionStore
    private var cancellables: Set<AnyCancellable> = []

    enum ConnectionState: Equatable {
        case checking
        case signedOut(message: String)
        case connecting(message: String)
        case connected(ConnectedServer)
        case failed(message: String)
        case savedConnectionFailed(message: String)
    }

    @Published var connectionState: ConnectionState = .checking
    @Published var plexLinkCode: String?

    let libraryCache: LibraryCache
    let refreshTracker = RefreshTracker()

    private let plexConnector: any PlexConnecting
    private let jellyfinConnector: any JellyfinConnecting
    private var activeConnector: (any MediaConnector)?
    private var restoreTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var hasRestored = false
    private var activeLibraryOrderServerID: String?
    private var activeLibraryOrder: [String] = []
    private var activeHiddenLibraryIDs: Set<String> = []
    private var cacheGeneration = 0
    private let playbackReportQueue = PlaybackReportQueue<PlaybackReportKey>()

    private struct PlaybackReportKey: Hashable {
        let id: MediaPlaybackID
        let sessionID: String
    }

    convenience init() {
        self.init(
            mediaSessionStore: MediaSessionStore(),
            plexConnector: PlexConnector(),
            jellyfinConnector: JellyfinConnector(),
            libraryCache: LibraryCache(storage: .defaultLocation())
        )
    }

    init(
        mediaSessionStore: MediaSessionStore,
        plexConnector: any PlexConnecting,
        jellyfinConnector: any JellyfinConnecting,
        libraryCache: LibraryCache
    ) {
        self.mediaSessionStore = mediaSessionStore
        self.plexConnector = plexConnector
        self.jellyfinConnector = jellyfinConnector
        self.libraryCache = libraryCache

        // Forward (throttled) cache changes so views observing AppModel still
        // repaint when the cache mutates. Tracker changes are NOT forwarded:
        // views that care about spinner state observe `refreshTracker`
        // directly, which keeps high-frequency in-flight churn from
        // re-rendering the entire UI.
        libraryCache.snapshotDidChange
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var connectedServer: ConnectedServer? {
        if case .connected(let server) = connectionState {
            return server
        }
        return nil
    }

    // MARK: - Connection lifecycle

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        await restoreSavedConnection()
    }

    func retrySavedConnection() {
        connectionState = .checking
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            await self?.restoreSavedConnection()
        }
    }

    private func restoreSavedConnection() async {
        if plexConnector.hasSavedConnection {
            activeConnector = plexConnector

            do {
                if let server = try await plexConnector.restoreConnection() {
                    plexLinkCode = nil
                    setConnectedServer(server)
                    return
                }
            } catch {
                guard !Task.isCancelled else { return }
                plexLinkCode = nil
                connectionState = .savedConnectionFailed(
                    message: "Freya couldn't connect to your saved Plex server. Check your network connection and try again."
                )
                return
            }
        }

        if jellyfinConnector.hasSavedConnection {
            activeConnector = jellyfinConnector

            do {
                if let server = try await jellyfinConnector.restoreConnection() {
                    plexLinkCode = nil
                    setConnectedServer(server)
                    return
                }
            } catch {
                guard !Task.isCancelled else { return }
                plexLinkCode = nil
                connectionState = .savedConnectionFailed(
                    message: "Freya couldn't connect to your saved Jellyfin server. Check your network connection and try again."
                )
                return
            }
        }

        connectionState = .signedOut(message: "Choose a server to connect.")
    }

    func prepareJellyfinSetup() {
        guard jellyfinConnector.hasSavedConnection else { return }
        refreshJellyfinConnection()
    }

    func connectJellyfin(serverURL: String, username: String, password: String) {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil
        activeConnector = jellyfinConnector
        connectionState = .connecting(message: "Connecting to Jellyfin...")

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let server = try await jellyfinConnector.connect(
                    serverURL: serverURL,
                    username: username,
                    password: password
                )
                self.setConnectedServer(server)
            } catch {
                self.forgetSavedJellyfinConnection()
                self.connectionState = .failed(message: self.jellyfinConnectionFailureMessage(for: error))
            }
        }
    }

    func preparePlexSetup() {
        if plexConnectorIsReady {
            refreshPlexConnection()
            return
        }

        startPlexLogin()
    }

    func startPlexLogin() {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil
        connectionState = .connecting(message: "Starting Plex sign-in...")

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let session = try await plexConnector.beginLogin()
                self.plexLinkCode = session.code
                self.connectionState = .connecting(message: "Waiting for approval...")
                await self.pollForPlexLogin(session: session)
            } catch {
                guard !Task.isCancelled else { return }
                self.connectionState = .failed(message: "Couldn't start Plex sign-in. Please try again.")
            }
        }
    }

    func cancelPlexSetup() {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil

        guard connectedServer == nil else { return }
        activeConnector = nil
        connectionState = .signedOut(message: "Choose a server to connect.")
    }

    func disconnectCurrentServer() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        invalidateCacheGeneration()
        refreshTracker.cancelAll()
        restoreTask?.cancel()
        pollTask?.cancel()
        plexConnector.disconnect()
        jellyfinConnector.disconnect()
        activeConnector = nil
        clearActiveLibraryOrder()
        ArtworkImageCache.shared.clear()
        URLCache.shared.removeAllCachedResponses()
        libraryCache.clear()
        plexLinkCode = nil
        connectionState = .signedOut(message: "Choose a server to connect.")
    }

    func clearCacheAndResync() {
        guard let server = connectedServer else { return }
        let clearedServer = server.clearingCachedItems()

        invalidateCacheGeneration()
        refreshTracker.cancelAll()
        ArtworkImageCache.shared.clear()
        libraryCache.clear()
        connectionState = .connected(clearedServer)

        refreshConnection()
        for library in clearedServer.libraries.map(\.reference) {
            refreshTracker.run(.library(library.id)) { [weak self] in
                await self?._resyncLibrary(library)
            }
        }
    }

    // MARK: - Library reordering / hiding

    func moveLibrary(at index: Int, by offset: Int) {
        guard case .connected(let server) = connectionState else { return }

        let destination = index + offset
        guard
            server.libraries.indices.contains(index),
            server.libraries.indices.contains(destination)
        else {
            return
        }

        var libraries = server.libraries
        let library = libraries.remove(at: index)
        libraries.insert(library, at: destination)
        rememberLibraryOrder(libraries.map(\.id), for: server)
        connectionState = .connected(server.settingLibraries(libraries))
    }

    func setLibraryHidden(_ isHidden: Bool, at index: Int) {
        guard case .connected(let server) = connectionState,
              server.libraries.indices.contains(index) else { return }

        var libraries = server.libraries
        let library = libraries[index]
        libraries[index] = library.settingHidden(isHidden)
        rememberHiddenLibraries(
            Set(libraries.filter(\.isHidden).map(\.id)),
            for: server
        )
        connectionState = .connected(server.settingLibraries(libraries))
    }

    // MARK: - Fire-and-forget refresh API
    //
    // Public refresh / mutation methods are non-async by design: views never
    // block on the network. Each method delegates to `refreshTracker.run`,
    // which dedups concurrent calls for the same key. The cache is the only
    // signal callers observe.

    /// Schedule a refresh of the active server's metadata in the background.
    func refreshConnection() {
        refreshTracker.run(.connection) { [weak self] in
            await self?._refreshConnection()
        }
    }

    func refreshAllLibraries(_ server: ConnectedServer) {
        refreshConnection()
        for library in server.libraries {
            refreshLibrary(library.reference)
        }
    }

    func isRefreshingAllLibraries(_ server: ConnectedServer) -> Bool {
        refreshTracker.isRefreshing(.connection)
            || server.libraries.contains {
                refreshTracker.isRefreshing(.library($0.id))
            }
    }

    /// Schedule a full recursive refresh of `library` in the background.
    func refreshLibrary(_ library: LibraryReference) {
        refreshTracker.run(.library(library.id)) { [weak self] in
            await self?._resyncLibrary(library)
        }
    }

    /// Schedule a recursive refresh of `item`'s children in the background.
    func refreshChildren(of item: MediaItem) {
        refreshTracker.run(.children(item.id)) { [weak self] in
            await self?._refreshChildrenWork(of: item, recursive: true)
        }
    }

    /// Schedule a refresh of a single item in the background.
    func refreshItem(_ item: MediaItem) {
        refreshTracker.run(.item(item.id)) { [weak self] in
            await self?._refreshItem(item)
        }
    }

    /// Apply the watch-state change optimistically and sync each affected leaf
    /// in the background. Reverts the cache on network failure. Never throws:
    /// the cache is the source of truth views observe.
    func setWatchStatus(for item: MediaItem, isWatched: Bool) {
        if libraryCache.item(item.id) == nil {
            libraryCache.ingest(item: item)
        }

        Task { [weak self] in
            await self?._applyAndSyncWatchStatus(for: item, isWatched: isWatched)
        }
    }

    /// Fire-and-forget timeline reporting. Always background, never blocks UI.
    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) {
        let connector = connector(for: id.providerID)
        playbackReportQueue.enqueue(
            for: PlaybackReportKey(id: id, sessionID: sessionID),
            isTerminal: state == .stopped
        ) {
            try? await connector.reportPlaybackTimeline(
                for: id,
                state: state,
                time: time,
                duration: duration,
                sessionID: sessionID
            )
        }
    }

    func stopPlaybackSession(for id: MediaPlaybackID, sessionID: String?) {
        guard let sessionID else { return }
        Task { [weak self] in
            await self?.connector(for: id.providerID).stopPlaybackSession(sessionID)
        }
    }

    func markPlaybackCompleted(for id: MediaPlaybackID, sessionID: String) {
        let previous = libraryCache.leaves(under: id.itemID)
        _ = libraryCache.applyOptimisticWatchStatus(for: id.itemID, isWatched: true)
        let connector = connector(for: id.providerID)

        playbackReportQueue.enqueueFinalization(
            for: PlaybackReportKey(id: id, sessionID: sessionID)
        ) { [weak self] in
            guard let self else { return }
            do {
                try await connector.markPlaybackCompleted(for: id)
                if let item = self.libraryCache.item(id.itemID) {
                    self.refreshItem(item)
                }
            } catch {
                self.libraryCache.revertWatchStatus(to: previous)
            }
        }
    }

    // MARK: - Synchronous request-response (user-initiated playback only)

    /// Resolve playback options for `id`. The user is initiating playback, so
    /// the caller genuinely needs the response back.
    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        try await connector(for: id.providerID).playbackOptions(for: id)
    }

    /// Resolve a playable URL. Same exception as `playbackOptions(for:)`.
    func playbackURL(
        for id: MediaPlaybackID,
        selection: MediaPlaybackSelection? = nil,
        sessionID: String,
        offsetMilliseconds: Int? = nil
    ) async throws -> MediaPlaybackResource {
        try await connector(for: id.providerID).playbackURL(
            for: id,
            selection: selection,
            sessionID: sessionID,
            offsetMilliseconds: offsetMilliseconds
        )
    }

    // MARK: - Internal implementations

    private func _refreshConnection() async {
        guard let activeConnector else { return }
        let generation = cacheGeneration
        let existingServer = connectedServer

        do {
            let server = try await activeConnector.refreshConnection()
            guard generation == cacheGeneration else { return }
            if plexLinkCode != nil {
                plexLinkCode = nil
            }
            setConnectedServer(server)
        } catch {
            if existingServer == nil {
                connectionState = .failed(message: "Couldn't connect to the current server.")
            }
        }
    }

    private func _resyncLibrary(_ library: LibraryReference) async {
        libraryCache.beginBatchUpdates()
        defer { libraryCache.endBatchUpdates() }
        await _refreshLibrary(library)
        await _warmLibraryChildren(library)
    }

    private func _refreshLibrary(_ library: LibraryReference) async {
        let generation = cacheGeneration
        guard isCurrentServer(providerID: library.providerID, serverID: library.serverID) else { return }

        let connector = connector(for: library.providerID)
        do {
            let items = try await connector.loadLibraryItems(for: library)
            guard generation == cacheGeneration,
                  isCurrentServer(providerID: library.providerID, serverID: library.serverID) else { return }
            libraryCache.ingest(items: items, asTopLevelOf: library.id)
        } catch {}
    }

    private func _refreshItem(_ item: MediaItem) async {
        let generation = cacheGeneration
        guard isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }

        let connector = connector(for: item.providerID)
        do {
            let fresh = try await connector.loadItem(item)
            guard generation == cacheGeneration,
                  isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }
            libraryCache.ingest(item: fresh)
        } catch {}
    }

    /// Refresh children of `item`. Recursive descents go through
    /// `refreshTracker` so concurrent walks (warm + user navigating into the
    /// same series, etc.) collapse to a single network fetch per item.
    private func _refreshChildrenWork(of item: MediaItem, recursive: Bool) async {
        let generation = cacheGeneration
        guard isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }
        guard !item.kind.isPlayable else { return }

        let connector = connector(for: item.providerID)
        let children: [MediaItem]
        do {
            children = try await connector.loadChildren(for: item)
        } catch {
            return
        }
        guard generation == cacheGeneration,
              isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }
        libraryCache.ingest(children: children, of: item.id)

        guard recursive else { return }

        await withTaskGroup(of: Void.self) { group in
            for child in children where !child.kind.isPlayable {
                if Task.isCancelled { break }
                group.addTask { [weak self] in
                    guard let self else { return }
                    await self.refreshTracker.run(.children(child.id)) { [weak self] in
                        await self?._refreshChildrenWork(of: child, recursive: true)
                    }.value
                }
            }
        }
    }

    private func _warmLibraryChildren(_ library: LibraryReference) async {
        let generation = cacheGeneration
        guard isCurrentServer(providerID: library.providerID, serverID: library.serverID) else { return }
        guard library.defaultItemKind == .series else { return }

        if libraryCache.libraryItems(for: library.id).isEmpty {
            await _refreshLibrary(library)
        }
        let topLevel = libraryCache.libraryItems(for: library.id)
        guard generation == cacheGeneration else { return }

        for item in topLevel where !item.kind.isPlayable {
            guard !Task.isCancelled else { return }
            await refreshTracker.run(.children(item.id)) { [weak self] in
                await self?._refreshChildrenWork(of: item, recursive: true)
            }.value
        }

        libraryCache.cacheLatestEpisodeAddedAt(for: topLevel.map(\.id))
    }

    private func _applyAndSyncWatchStatus(for item: MediaItem, isWatched: Bool) async {
        let generation = cacheGeneration
        guard isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }

        // Make sure leaves are loaded before we try to flip them.
        if !item.kind.isPlayable && libraryCache.leaves(under: item.id).isEmpty {
            await refreshTracker.run(.children(item.id)) { [weak self] in
                await self?._refreshChildrenWork(of: item, recursive: true)
            }.value
        }
        guard generation == cacheGeneration,
              isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }

        let previous = libraryCache.leaves(under: item.id)
        let updated = libraryCache.applyOptimisticWatchStatus(for: item.id, isWatched: isWatched)
        guard !updated.isEmpty else { return }

        let calls: [(connector: any MediaConnector, playbackID: MediaPlaybackID)] = updated.compactMap { target in
            guard let playbackID = target.playbackID else { return nil }
            return (connector(for: target.providerID), playbackID)
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for call in calls {
                    let connector = call.connector
                    let playbackID = call.playbackID
                    group.addTask {
                        try await connector.setWatchStatus(for: playbackID, isWatched: isWatched)
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            guard generation == cacheGeneration,
                  isCurrentServer(providerID: item.providerID, serverID: item.serverID) else { return }
            libraryCache.revertWatchStatus(to: previous)
        }
    }

    // MARK: - Plex / Jellyfin connection helpers

    private var plexConnectorIsReady: Bool {
        activeConnector?.providerID == .plex || plexConnector.hasSavedConnection
    }

    private func refreshPlexConnection() {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil
        activeConnector = plexConnector
        let isRestoringSavedConnection = connectedServer == nil

        if connectedServer == nil {
            connectionState = .connecting(message: "Loading your server...")
        }

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let server = try await plexConnector.refreshConnection()
                self.setConnectedServer(server)
            } catch {
                guard !Task.isCancelled else { return }
                if isRestoringSavedConnection {
                    self.forgetSavedPlexConnection()
                    self.connectionState = .signedOut(
                        message: "We couldn't connect with the saved Plex sign-in. Sign in again."
                    )
                } else {
                    self.connectionState = .failed(
                        message: "We signed into Plex, but couldn't connect to a Plex Media Server for this account."
                    )
                }
            }
        }
    }

    private func refreshJellyfinConnection() {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil
        activeConnector = jellyfinConnector
        let isRestoringSavedConnection = connectedServer == nil

        if connectedServer == nil {
            connectionState = .connecting(message: "Loading your Jellyfin server...")
        }

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let server = try await jellyfinConnector.refreshConnection()
                self.setConnectedServer(server)
            } catch {
                if isRestoringSavedConnection {
                    self.forgetSavedJellyfinConnection()
                    self.connectionState = .signedOut(
                        message: "We couldn't connect with the saved Jellyfin sign-in. Sign in again."
                    )
                } else {
                    self.connectionState = .failed(message: self.jellyfinConnectionFailureMessage(for: error))
                }
            }
        }
    }

    private func pollForPlexLogin(session: PlexLoginSession) async {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && Date() < session.expiresAt {
                do {
                    if let server = try await plexConnector.completeLoginIfAuthorized(session: session) {
                        self.activeConnector = self.plexConnector
                        self.plexLinkCode = nil
                        self.setConnectedServer(server)
                        return
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    self.forgetSavedPlexConnection()
                    self.plexLinkCode = nil
                    self.connectionState = .failed(message: self.plexSignInFailureMessage(for: error))
                    return
                }

                try? await Task.sleep(for: .seconds(2))
            }

            if !Task.isCancelled {
                self.plexLinkCode = nil
                self.connectionState = .failed(message: "That Plex code expired. Please try again.")
            }
        }

        await pollTask?.value
    }

    private func connector(for providerID: MediaProviderID) -> any MediaConnector {
        switch providerID {
        case .plex:
            return plexConnector
        case .jellyfin:
            return jellyfinConnector
        }
    }

    private func forgetSavedPlexConnection() {
        plexConnector.disconnect()
        if activeConnector?.providerID == .plex {
            activeConnector = nil
        }
        plexLinkCode = nil
    }

    private func forgetSavedJellyfinConnection() {
        jellyfinConnector.disconnect()
        if activeConnector?.providerID == .jellyfin {
            activeConnector = nil
        }
    }

    private func plexSignInFailureMessage(for error: any Error) -> String {
        let message = error.localizedDescription

        if message == String(describing: error) {
            return "Plex approved Freya, but we couldn't finish connecting. Please try again."
        }

        return message
    }

    private func jellyfinConnectionFailureMessage(for error: any Error) -> String {
        let message = error.localizedDescription

        if message == String(describing: error) {
            return "Couldn't connect to Jellyfin. Check the server URL and credentials."
        }

        return message
    }

    private func invalidateCacheGeneration() {
        cacheGeneration += 1
    }

    private func isCurrentServer(providerID: MediaProviderID, serverID: String) -> Bool {
        guard let server = connectedServer else { return false }
        return server.providerID == providerID && server.serverID == serverID
    }

    // MARK: - Library order / hidden state

    private func setConnectedServer(_ server: ConnectedServer) {
        if activeLibraryOrderServerID != server.id {
            loadActiveLibraryState(for: server)
        }

        let server = applyActiveLibraryOrder(to: server)
        libraryCache.install(server: server)
        let metadataServer = server.clearingCachedItems()
        guard connectedServer != metadataServer else { return }
        connectionState = .connected(metadataServer)
    }

    private func rememberLibraryOrder(_ libraryIDs: [String], for server: ConnectedServer) {
        activeLibraryOrderServerID = server.id
        activeLibraryOrder = libraryIDs
        mediaSessionStore.setLibraryOrder(libraryIDs, providerID: server.providerID, serverID: server.serverID)
    }

    private func rememberHiddenLibraries(_ libraryIDs: Set<String>, for server: ConnectedServer) {
        activeLibraryOrderServerID = server.id
        activeHiddenLibraryIDs = libraryIDs
        mediaSessionStore.setHiddenLibraryIDs(libraryIDs, providerID: server.providerID, serverID: server.serverID)
    }

    private func clearActiveLibraryOrder() {
        activeLibraryOrderServerID = nil
        activeLibraryOrder = []
        activeHiddenLibraryIDs = []
    }

    private func loadActiveLibraryState(for server: ConnectedServer) {
        activeLibraryOrderServerID = server.id
        activeLibraryOrder = mediaSessionStore.libraryOrder(
            providerID: server.providerID,
            serverID: server.serverID
        )
        activeHiddenLibraryIDs = mediaSessionStore.hiddenLibraryIDs(
            providerID: server.providerID,
            serverID: server.serverID
        )
    }

    private func applyActiveLibraryOrder(to server: ConnectedServer) -> ConnectedServer {
        guard
            activeLibraryOrderServerID == server.id,
            !activeLibraryOrder.isEmpty || !activeHiddenLibraryIDs.isEmpty
        else {
            return server.settingLibraries(
                server.libraries.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            )
        }

        let rankByLibraryID = Dictionary(
            uniqueKeysWithValues: activeLibraryOrder.enumerated().map { ($1, $0) }
        )
        let sortedNew = server.libraries
            .filter { rankByLibraryID[$0.id] == nil }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let libraries = server.libraries
            .compactMap { library -> (LibraryShelf, Int)? in
                if let rank = rankByLibraryID[library.id] {
                    return (library, rank)
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
            + sortedNew
        let result = libraries.map { library in
            library.settingHidden(activeHiddenLibraryIDs.contains(library.id))
        }

        rememberLibraryOrder(result.map(\.id), for: server)
        rememberHiddenLibraries(
            Set(result.filter(\.isHidden).map(\.id)),
            for: server
        )
        return server.settingLibraries(result)
    }
}

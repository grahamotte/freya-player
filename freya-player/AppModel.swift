import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private let mediaSessionStore = MediaSessionStore()

    enum ConnectionState {
        case checking
        case signedOut(message: String)
        case connecting(message: String)
        case connected(ConnectedServer)
        case failed(message: String)
    }

    @Published var connectionState: ConnectionState = .checking
    @Published var plexLinkCode: String?

    private let plexConnector = PlexConnector()
    private let jellyfinConnector = JellyfinConnector()
    private var activeConnector: (any MediaConnector)?
    private var restoreTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var hasRestored = false
    private var activeLibraryOrderServerID: String?
    private var activeLibraryOrder: [String] = []
    private var activeHiddenLibraryIDs: Set<String> = []

    var connectedServer: ConnectedServer? {
        if case .connected(let server) = connectionState {
            return server
        }
        return nil
    }

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        do {
            if let server = try await plexConnector.restoreConnection() {
                activeConnector = plexConnector
                plexLinkCode = nil
                setConnectedServer(server)
                return
            }
        } catch {}

        do {
            if let server = try await jellyfinConnector.restoreConnection() {
                activeConnector = jellyfinConnector
                plexLinkCode = nil
                setConnectedServer(server)
                return
            }
        } catch {}

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
                await MainActor.run {
                    self.setConnectedServer(server)
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .failed(message: "Couldn't sign into Jellyfin. Check the server URL and credentials.")
                }
            }
        }
    }

    func refreshConnection() async {
        guard let activeConnector else { return }
        let existingServer = connectedServer

        do {
            let server = try await activeConnector.refreshConnection()
            plexLinkCode = nil
            setConnectedServer(server)
        } catch {
            if existingServer == nil {
                connectionState = .failed(message: "Couldn't connect to the current server.")
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
                await MainActor.run {
                    self.plexLinkCode = session.code
                    self.connectionState = .connecting(message: "Waiting for approval...")
                }
                await self.pollForPlexLogin(session: session)
            } catch {
                await MainActor.run {
                    self.connectionState = .failed(message: "Couldn't start Plex sign-in. Please try again.")
                }
            }
        }
    }

    func disconnectCurrentServer() {
        if let server = connectedServer {
            mediaSessionStore.clearLibraryManagement(providerID: server.providerID, serverID: server.serverID)
        }

        restoreTask?.cancel()
        pollTask?.cancel()
        activeConnector?.disconnect()
        activeConnector = nil
        clearActiveLibraryOrder()
        plexLinkCode = nil
        connectionState = .signedOut(message: "Choose a server to connect.")
    }

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

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        try await connector(for: library.providerID).loadLibraryItems(for: library)
    }

    func loadItem(_ item: MediaItem) async throws -> MediaItem {
        try await connector(for: item.providerID).loadItem(item)
    }

    func loadChildren(for item: MediaItem) async throws -> [MediaItem] {
        try await connector(for: item.providerID).loadChildren(for: item)
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        try await connector(for: id.providerID).playbackOptions(for: id)
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection? = nil) async throws -> URL {
        try await connector(for: id.providerID).playbackURL(for: id, selection: selection)
    }

    func reportPlaybackTimeline(
        for id: MediaPlaybackID,
        state: MediaPlaybackTimelineState,
        time: Int,
        duration: Int?,
        sessionID: String
    ) async {
        try? await connector(for: id.providerID).reportPlaybackTimeline(
            for: id,
            state: state,
            time: time,
            duration: duration,
            sessionID: sessionID
        )
    }

    func markPlaybackCompleted(for id: MediaPlaybackID) async {
        try? await connector(for: id.providerID).markPlaybackCompleted(for: id)
    }

    func watchStatusTargets(for item: MediaItem) async throws -> [MediaItem] {
        if item.playbackID != nil {
            return [item]
        }

        let children = try await loadChildren(for: item)
        return try await watchStatusTargets(in: children)
    }

    func setWatchStatus(for id: MediaPlaybackID, isWatched: Bool) async throws {
        try await connector(for: id.providerID).setWatchStatus(for: id, isWatched: isWatched)
    }

    func setWatchStatus(for item: MediaItem, isWatched: Bool) async throws {
        let targets = try await watchStatusTargets(for: item).filter {
            if isWatched {
                return !$0.isWatched
            }

            return $0.isWatched || ($0.progress ?? 0) > 0 || ($0.resumeOffsetMilliseconds ?? 0) > 0
        }

        for target in targets {
            guard let playbackID = target.playbackID else { continue }
            try await setWatchStatus(for: playbackID, isWatched: isWatched)
        }
    }

    func markWatched(_ item: MediaItem) async throws {
        try await setWatchStatus(for: item, isWatched: true)
    }

    func markUnwatched(_ item: MediaItem) async throws {
        try await setWatchStatus(for: item, isWatched: false)
    }

    private func watchStatusTargets(in items: [MediaItem]) async throws -> [MediaItem] {
        var targets: [MediaItem] = []

        for item in items {
            if item.playbackID != nil {
                targets.append(item)
            } else {
                targets += try await watchStatusTargets(for: item)
            }
        }

        return targets
    }

    private var plexConnectorIsReady: Bool {
        activeConnector?.providerID == .plex || PlexSessionStore().userToken != nil
    }

    private func refreshPlexConnection() {
        restoreTask?.cancel()
        pollTask?.cancel()
        plexLinkCode = nil
        activeConnector = plexConnector

        if connectedServer == nil {
            connectionState = .connecting(message: "Loading your server...")
        }

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let server = try await plexConnector.refreshConnection()
                await MainActor.run {
                    self.setConnectedServer(server)
                }
            } catch {
                await MainActor.run {
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

        if connectedServer == nil {
            connectionState = .connecting(message: "Loading your Jellyfin server...")
        }

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let server = try await jellyfinConnector.refreshConnection()
                await MainActor.run {
                    self.setConnectedServer(server)
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .failed(message: "Couldn't restore the saved Jellyfin connection.")
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
                        await MainActor.run {
                            self.activeConnector = self.plexConnector
                            self.plexLinkCode = nil
                            self.setConnectedServer(server)
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.plexLinkCode = nil
                        self.connectionState = .failed(message: "Plex sign-in stopped responding. Please try again.")
                    }
                    return
                }

                try? await Task.sleep(for: .seconds(2))
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.plexLinkCode = nil
                    self.connectionState = .failed(message: "That Plex code expired. Please try again.")
                }
            }
        }

        await pollTask?.value
    }

    private func connector(for providerID: MediaProviderID) throws -> any MediaConnector {
        switch providerID {
        case .plex:
            return plexConnector
        case .jellyfin:
            return jellyfinConnector
        }
    }

    private func setConnectedServer(_ server: ConnectedServer) {
        if activeLibraryOrderServerID != server.id {
            loadActiveLibraryState(for: server)
        }

        connectionState = .connected(applyActiveLibraryOrder(to: server))
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
            return server
        }

        let rankByLibraryID = Dictionary(
            uniqueKeysWithValues: activeLibraryOrder.enumerated().map { ($1, $0) }
        )
        let fallbackRank = activeLibraryOrder.count
        let libraries = server.libraries.enumerated()
            .sorted { lhs, rhs in
                let leftRank = rankByLibraryID[lhs.element.id] ?? (fallbackRank + lhs.offset)
                let rightRank = rankByLibraryID[rhs.element.id] ?? (fallbackRank + rhs.offset)
                return leftRank < rightRank
            }
            .map(\.element)
            .map { library in
                library.settingHidden(activeHiddenLibraryIDs.contains(library.id))
            }

        rememberLibraryOrder(libraries.map(\.id), for: server)
        rememberHiddenLibraries(
            Set(libraries.filter(\.isHidden).map(\.id)),
            for: server
        )
        return server.settingLibraries(libraries)
    }
}

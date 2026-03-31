import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
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
                connectionState = .connected(server)
            } else {
                connectionState = .signedOut(message: "Link your Plex account to discover a server.")
            }
        } catch {
            connectionState = .failed(message: "Couldn't restore the saved Plex connection.")
        }
    }

    func refreshConnection() async {
        guard let activeConnector else { return }
        let existingServer = connectedServer

        do {
            let server = try await activeConnector.refreshConnection()
            plexLinkCode = nil
            connectionState = .connected(server)
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
        restoreTask?.cancel()
        pollTask?.cancel()
        activeConnector?.disconnect()
        activeConnector = nil
        plexLinkCode = nil
        connectionState = .signedOut(message: "Link your Plex account to discover a server.")
    }

    func loadLibraryItems(for library: LibraryReference) async throws -> [MediaItem] {
        try await connector(for: library.providerID).loadLibraryItems(for: library)
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
                    self.connectionState = .connected(server)
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
                            self.connectionState = .connected(server)
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
}

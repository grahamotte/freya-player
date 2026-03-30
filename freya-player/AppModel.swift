import Combine
import Foundation

enum MediaPlaybackID: Hashable {
    case plex(String)
    case jellyfin(String)
}

struct MediaPlaybackOptions: Equatable {
    let audioOptions: [MediaPlaybackOption]
    let subtitleOptions: [MediaPlaybackOption]
    let selectedAudioID: String?
    let selectedSubtitleID: String?
    let kind: Kind

    var requiresSelection: Bool {
        audioOptions.count > 1 || !subtitleOptions.isEmpty
    }

    enum Kind: Equatable {
        case plex(PlexPlaybackSelectionContext)
        case jellyfin
    }
}

struct MediaPlaybackOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct MediaPlaybackSelection: Equatable {
    let audioID: String?
    let subtitleID: String?
}

struct PlexPlaybackSelectionContext: Equatable {
    let ratingKey: String
    let partID: String
}

@MainActor
final class AppModel: ObservableObject {
    enum PlexState {
        case checking
        case signedOut(message: String)
        case waitingForLink(code: String)
        case connected(PlexConnectionSummary)
        case failed(message: String)
    }

    @Published var plexState: PlexState = .checking

    private let client = PlexClient()
    private let store = PlexSessionStore()
    private var restoreTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var hasRestored = false

    var connectedSummary: PlexConnectionSummary? {
        if case .connected(let summary) = plexState {
            return summary
        }
        return nil
    }

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        guard let userToken = store.userToken else {
            plexState = .signedOut(message: "Link your Plex account to discover a server.")
            return
        }

        await connect(using: userToken)
    }

    func refreshPlex() {
        guard let userToken = store.userToken else { return }

        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            await self?.connect(using: userToken)
        }
    }

    func startPlexLogin() {
        restoreTask?.cancel()
        pollTask?.cancel()

        restoreTask = Task { [weak self] in
            guard let self else { return }

            do {
                let pin = try await client.createPin()
                await MainActor.run {
                    self.plexState = .waitingForLink(code: pin.code)
                }
                await self.pollForAuth(pin: pin)
            } catch {
                await MainActor.run {
                    self.plexState = .failed(message: "Couldn't start Plex sign-in. Please try again.")
                }
            }
        }
    }

    func disconnectPlex() {
        restoreTask?.cancel()
        pollTask?.cancel()
        store.clear()
        plexState = .signedOut(message: "Link your Plex account to discover a server.")
    }

    func preparePlexSetup() {
        if store.userToken != nil {
            refreshPlex()
            return
        }

        if case .signedOut = plexState {
            startPlexLogin()
        }
    }

    func playbackOptions(for id: MediaPlaybackID) async throws -> MediaPlaybackOptions? {
        switch id {
        case .plex(let ratingKey):
            guard let summary = connectedSummary else {
                throw PlaybackError.unavailable
            }

            return try await client.playbackOptions(for: ratingKey, connection: summary)
        case .jellyfin:
            throw PlaybackError.unavailable
        }
    }

    func playbackURL(for id: MediaPlaybackID, selection: MediaPlaybackSelection? = nil) async throws -> URL {
        switch id {
        case .plex(let ratingKey):
            guard let summary = connectedSummary else {
                throw PlaybackError.unavailable
            }

            return try await client.playbackURL(
                for: ratingKey,
                connection: summary,
                selection: selection
            )
        case .jellyfin:
            throw PlaybackError.unavailable
        }
    }

    private func pollForAuth(pin: PlexPin) async {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            let deadline = Date().addingTimeInterval(TimeInterval(pin.expiresIn ?? 900))

            while !Task.isCancelled && Date() < deadline {
                do {
                    if let userToken = try await client.checkPin(id: pin.id) {
                        store.userToken = userToken
                        await connect(using: userToken)
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.plexState = .failed(message: "Plex sign-in stopped responding. Please try again.")
                    }
                    return
                }

                try? await Task.sleep(for: .seconds(2))
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.plexState = .failed(message: "That Plex code expired. Please try again.")
                }
            }
        }

        await pollTask?.value
    }

    private func connect(using userToken: String) async {
        plexState = .checking

        do {
            let summary = try await client.connect(
                userToken: userToken,
                preferredServerID: store.serverIdentifier
            )

            store.serverIdentifier = summary.serverID
            plexState = .connected(summary)
        } catch {
            plexState = .failed(message: "We signed into Plex, but couldn't connect to a Plex Media Server for this account.")
        }
    }
}

private enum PlaybackError: Error {
    case unavailable
}

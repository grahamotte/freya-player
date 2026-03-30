import Combine
import SwiftUI

struct HomeView: View {
    @StateObject private var model = HomeModel()

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 72) {
                    NavigationLink(value: Route.plex) {
                        serviceButton(title: "Plex", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 28))
                    .controlSize(.large)

                    NavigationLink(value: Route.jellyfin) {
                        serviceButton(title: "Jellyfin", systemImage: "square.stack.3d.up.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 28))
                    .controlSize(.large)
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundGradient)
            .navigationTitle("Freya Player")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plex:
                    PlexConnectView(model: model)
                case .jellyfin:
                    JellyfinComingSoonView()
                }
            }
            .task {
                await model.restoreIfNeeded()
            }
        }
    }

    private func serviceButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
            .frame(width: 280, height: 140)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.04, green: 0.05, blue: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

@MainActor
final class HomeModel: ObservableObject {
    enum PlexState {
        case checking
        case signedOut(message: String)
        case waitingForLink(code: String)
        case connected(PlexConnectionSummary)
        case failed(message: String)
    }

    @Published var plexState: PlexState = .checking

    var hasSavedPlexSession: Bool {
        store.userToken != nil
    }

    private let client = PlexClient()
    private let store = PlexSessionStore()
    private var restoreTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var hasRestored = false

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        guard let userToken = store.userToken else {
            plexState = .signedOut(message: "Link your Plex account to discover a server and load its libraries.")
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
        plexState = .signedOut(message: "Link your Plex account to discover a server and load its libraries.")
    }

    func preparePlexScreen() {
        if store.userToken != nil {
            refreshPlex()
            return
        }

        if case .signedOut = plexState {
            startPlexLogin()
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
                    self.plexState = .failed(message: "That Plex code expired. Start over to get a new one.")
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

private enum Route: Hashable {
    case plex
    case jellyfin
}

private struct PlexConnectView: View {
    @ObservedObject var model: HomeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Label("Plex", systemImage: "play.rectangle.fill")
                    .font(.title3.weight(.semibold))

                switch model.plexState {
                case .checking:
                    ProgressView("Checking saved Plex connection...")

                case .signedOut(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button("Connect With Plex") {
                        model.startPlexLogin()
                    }

                case .waitingForLink(let code):
                    Text("Visit this link in your browser")
                        .foregroundStyle(.secondary)

                    Text("plex.tv/link")
                        .font(.headline)

                    Text("and enter this code")
                        .foregroundStyle(.secondary)

                    Text(code)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospaced()

                    Text("Waiting for approval...")
                        .foregroundStyle(.secondary)

                case .connected(let summary):
                    Label("Connected to \(summary.serverName)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text(summary.serverURL)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if summary.libraries.isEmpty {
                        Text("Connected, but this server has no libraries yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(summary.libraries) { library in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(library.title)
                                                .font(.headline)

                                            Text(library.type.capitalized)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text("#\(library.key)")
                                            .font(.footnote.monospaced())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 360)
                    }

                    HStack(spacing: 16) {
                        Button("Refresh") {
                            model.refreshPlex()
                        }

                        Button("Disconnect", role: .destructive) {
                            model.disconnectPlex()
                        }
                    }

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button("Try Again") {
                            model.startPlexLogin()
                        }

                        if model.hasSavedPlexSession {
                            Button("Clear Saved Session", role: .destructive) {
                                model.disconnectPlex()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
            )

            Button("Cancel") {
                dismiss()
            }

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .navigationTitle("Plex")
        .task {
            model.preparePlexScreen()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.04, green: 0.05, blue: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct JellyfinComingSoonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 18) {
                Text("Coming soon...")
                    .font(.title2.weight(.semibold))

                Text("Jellyfin support will come after the first Plex connection flow is in place.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720)
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
            )

            Button("Cancel") {
                dismiss()
            }

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .navigationTitle("Jellyfin")
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.04, green: 0.05, blue: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

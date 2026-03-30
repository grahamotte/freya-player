import Combine
import SwiftUI

struct HomeView: View {
    @StateObject private var model = HomeModel()
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            rootView
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plexConnect:
                    PlexConnectView(model: model)
                case .plexAccount:
                    PlexAccountView(model: model, path: $path)
                case .jellyfin:
                    JellyfinComingSoonView()
                }
            }
            .task {
                await model.restoreIfNeeded()
            }
            .onChange(of: model.connectedSummary?.serverID) { _, serverID in
                if serverID != nil {
                    path.removeAll()
                }
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let summary = model.connectedSummary {
            PlexServerHomeView(summary: summary)
        } else if case .checking = model.plexState {
            ProgressView("Checking saved Plex connection...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundGradient)
        } else {
            VStack {
                HStack(spacing: 72) {
                    Button {
                        path.append(.plexConnect)
                    } label: {
                        serviceButton(title: "Plex", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 28))
                    .controlSize(.large)

                    Button {
                        path.append(.jellyfin)
                    } label: {
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

private enum Route: Hashable {
    case plexConnect
    case plexAccount
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

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        model.startPlexLogin()
                    }

                case .connected:
                    ProgressView("Loading your server...")
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(28)
            .background(panelBackground)

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
}

private struct PlexServerHomeView: View {
    let summary: PlexConnectionSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text(summary.serverName)
                    .font(.largeTitle.weight(.semibold))

                ForEach(summary.libraries) { library in
                    PlexLibraryShelfView(library: library, summary: summary)
                }

                NavigationLink(value: Route.plexAccount) {
                    Text("Manage Account")
                        .frame(minWidth: 260)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 12)
                .focusSection()
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }
}

private struct PlexLibraryShelfView: View {
    let library: PlexLibrarySection
    let summary: PlexConnectionSummary
    @FocusState private var focusedItemID: String?

    private var shelfStyle: PlexShelfStyle {
        switch library.type {
        case "movie", "show":
            return .poster
        default:
            return .wide
        }
    }

    private var selectedItem: PlexMediaItem? {
        library.items.first(where: { $0.id == focusedItemID }) ?? library.items.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(library.title)
                .font(.title3.weight(.semibold))

            if library.items.isEmpty {
                Text("No recent items yet.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 40) {
                        ForEach(library.items) { item in
                            Button {
                            } label: {
                                PlexArtworkView(
                                    url: item.artworkURL(
                                        baseURL: summary.serverURL,
                                        token: summary.serverToken,
                                        width: shelfStyle.imageSize.width,
                                        height: shelfStyle.imageSize.height,
                                        preferCoverArt: shelfStyle == .wide
                                    ),
                                    aspectRatio: shelfStyle.aspectRatio
                                )
                                .containerRelativeFrame(.horizontal, count: shelfStyle.columns, spacing: 40)
                            }
                            .focused($focusedItemID, equals: item.id)
                            .accessibilityLabel(item.title)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedItem?.title ?? "")
                        .font(.body)
                        .lineLimit(2, reservesSpace: true)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 72, alignment: .topLeading)
            }
        }
        .focusSection()
    }
}

private struct PlexAccountView: View {
    @ObservedObject var model: HomeModel
    @Binding var path: [Route]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text("Logged In")
                    .font(.title3.weight(.semibold))

                Text(model.connectedSummary?.accountName ?? "Plex")
                    .font(.title2.weight(.semibold))

                Button("Disconnect", role: .destructive) {
                    model.disconnectPlex()
                    path.removeAll()
                }

                Button("Back") {
                    dismiss()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(28)
            .background(panelBackground)

            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .navigationTitle("Account")
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
            .background(panelBackground)

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
}

private struct PlexArtworkView: View {
    let url: URL?
    let aspectRatio: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}

private enum PlexShelfStyle: Equatable {
    case poster
    case wide

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .wide:
            return 16 / 9
        }
    }

    var columns: Int {
        switch self {
        case .poster:
            return 6
        case .wide:
            return 8
        }
    }

    var imageSize: (width: Int, height: Int) {
        switch self {
        case .poster:
            return (480, 720)
        case .wide:
            return (640, 360)
        }
    }
}

private var panelBackground: some View {
    RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(Color.white.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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

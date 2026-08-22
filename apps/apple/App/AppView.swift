import SwiftUI

struct AppView: View {
    @StateObject private var model: AppModel
    @State private var path: [AppRoute] = []

    @MainActor
    init(model: AppModel) {
        _model = StateObject(wrappedValue: model)
    }

    @MainActor
    init() {
        _model = StateObject(wrappedValue: AppModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .plexSetup:
                        PlexSetupPage(model: model)
                    case .jellyfinSetup:
                        JellyfinSetupPage(model: model)
                    case .about:
                        AboutPage()
                    case .plexSettings:
                        PlexSettingsPage(model: model, path: $path)
                    case .jellyfinSettings:
                        JellyfinSettingsPage(model: model, path: $path)
                    case .library(let library):
                        libraryPage(for: library)
                    case .movie(let item):
                        MovieItemPage(model: model, item: item)
                    case .series(let item):
                        TvSeriesItemPage(model: model, item: item)
                    case .season(let item):
                        TvSeasonItemPage(model: model, item: item)
                    case .episode(let item):
                        TvEpisodeItemPage(model: model, item: item)
                    case .other(let item):
                        OtherItemPage(model: model, item: item)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToAbout)) { _ in
                    path.append(.about)
                }
                .task {
                    await model.restoreIfNeeded()
                }
                .onChange(of: model.connectedServer?.id) { _, serverID in
                    if serverID != nil {
                        path.removeAll()
                    }
                }
        }
        .task(id: model.connectedServer?.id) {
            guard let server = model.connectedServer else { return }
            await PollingLoop.run {
                guard let currentServer = model.connectedServer, currentServer.id == server.id else { return }
                model.refreshAllLibrariesIfStale(currentServer)
            }
        }
        .alert("Connection Failed", isPresented: savedConnectionFailurePresented) {
            Button("Retry", role: .cancel) {
                model.retrySavedConnection()
            }
            Button("Deactivate", role: .destructive) {
                model.disconnectCurrentServer()
            }
        } message: {
            Text(savedConnectionFailureMessage ?? "")
        }
        .appChrome()
    }

    private var savedConnectionFailurePresented: Binding<Bool> {
        Binding(
            get: { savedConnectionFailureMessage != nil },
            set: { _ in }
        )
    }

    private var savedConnectionFailureMessage: String? {
        guard case .savedConnectionFailed(let message) = model.connectionState else { return nil }
        return message
    }

    @ViewBuilder
    private var rootView: some View {
        if let server = model.connectedServer {
            LibrariesPage(model: model, server: server, path: $path)
        } else if case .checking = model.connectionState {
            ProgressView("Checking saved connections...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else if case .savedConnectionFailed = model.connectionState {
            ProgressView("Checking saved connections...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else if case .connecting(let message) = model.connectionState {
            ProgressView(message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else {
            ProviderPickerView()
        }
    }

    @ViewBuilder
    private func libraryPage(for library: LibraryReference) -> some View {
        switch library.defaultItemKind {
        case .movie:
            MovieLibraryPage(model: model, library: library, path: $path)
        case .series, .season, .episode:
            TvLibraryPage(model: model, library: library, path: $path)
        case .other:
            OtherLibraryPage(model: model, library: library, path: $path)
        }
    }
}

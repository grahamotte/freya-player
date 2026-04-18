import SwiftUI

struct AppView: View {
    @StateObject private var model = AppModel()
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .plexSetup:
                        PlexSetupPage(model: model)
                    case .jellyfinSetup:
                        JellyfinSetupPage(model: model)
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
                .task {
                    await model.restoreIfNeeded()
                }
                .onChange(of: model.connectedServer?.id) { _, serverID in
                    if serverID != nil {
                        path.removeAll()
                    }
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let server = model.connectedServer {
            LibrariesPage(model: model, server: server, path: $path)
        } else if case .checking = model.connectionState {
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

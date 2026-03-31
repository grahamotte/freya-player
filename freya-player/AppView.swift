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
                        PlexSetupView(model: model)
                    case .jellyfinSetup:
                        JellyfinSetupView()
                    case .plexSettings:
                        PlexSettingsView(model: model, path: $path)
                    case .jellyfinSettings:
                        JellyfinSettingsView()
                    case .library(let library):
                        LibraryPageView(model: model, library: library, path: $path)
                    case .movie(let item):
                        ShowMovieView(model: model, item: item)
                    case .series(let item):
                        ShowSeriesView(model: model, item: item)
                    case .season(let item):
                        ShowSeasonView(model: model, item: item)
                    case .episode(let item):
                        ShowEpisodeView(model: model, item: item)
                    case .other(let item):
                        ShowOtherItemView(model: model, item: item)
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
            LibrariesView(model: model, server: server, path: $path)
        } else if case .checking = model.connectionState {
            ProgressView("Checking saved Plex connection...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else if case .connecting(let message) = model.connectionState {
            ProgressView(message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else {
            PickServerView()
        }
    }
}

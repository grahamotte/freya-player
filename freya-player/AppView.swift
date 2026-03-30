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
                    case .movieLibrary(let title):
                        MovieLibraryIndexView(title: title)
                    case .movie(let title):
                        ShowMovieView(title: title)
                    case .tvLibrary(let title):
                        TVLibraryIndexView(title: title)
                    case .series(let title):
                        ShowSeriesView(title: title)
                    case .season(let title):
                        ShowSeasonView(title: title)
                    case .episode(let title):
                        ShowEpisodeView(title: title)
                    case .otherLibrary(let title):
                        OtherLibraryIndexView(title: title)
                    case .other(let title):
                        ShowOtherItemView(title: title)
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
            LibrariesView(summary: summary)
        } else if case .checking = model.plexState {
            ProgressView("Checking saved Plex connection...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        } else {
            PickServerView()
        }
    }
}

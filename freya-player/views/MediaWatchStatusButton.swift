import SwiftUI

struct MediaWatchStatusButton: View {
    @ObservedObject var model: AppModel
    @Binding var item: MediaItem

    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        if item.playbackID != nil {
            MediaWatchStatusMenu(
                title: MediaWatchStatusDisplay.title(progress: item.progress, isWatched: item.isWatched),
                progress: item.progress,
                isWatched: item.isWatched,
                isUpdating: isUpdating,
                errorMessage: errorMessage,
                onMarkWatched: {
                    Task {
                        await setWatchStatus(true)
                    }
                },
                onMarkUnwatched: {
                    Task {
                        await setWatchStatus(false)
                    }
                }
            )
        }
    }

    private func setWatchStatus(_ isWatched: Bool) async {
        guard let playbackID = item.playbackID else { return }
        let previousItem = item
        item = item.settingWatchStatus(isWatched)
        errorMessage = nil

        isUpdating = true
        defer { isUpdating = false }

        do {
            try await model.setWatchStatus(for: playbackID, isWatched: isWatched)
        } catch {
            item = previousItem
            errorMessage = "Couldn't update watch status."
        }
    }
}

struct MediaCollectionWatchStatusButton: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    @State private var episodes: [MediaItem] = []
    @State private var displayItem: MediaItem
    @State private var isLoading = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    init(model: AppModel, item: MediaItem) {
        self.model = model
        self.item = item
        _displayItem = State(initialValue: item)
    }

    var body: some View {
        MediaWatchStatusMenu(
            title: MediaWatchStatusDisplay.title(progress: displayItem.progress, isWatched: displayItem.isWatched),
            progress: displayItem.progress,
            isWatched: displayItem.isWatched,
            isUpdating: isUpdating,
            errorMessage: errorMessage,
            onMarkWatched: {
                Task {
                    await setEpisodeWatchStatus(true)
                }
            },
            onMarkUnwatched: {
                Task {
                    await setEpisodeWatchStatus(false)
                }
            }
        )
        .disabled(isLoading || isUpdating)
        .task(id: item.id) {
            await loadEpisodes()
        }
    }

    private func loadEpisodes() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedEpisodes = try await episodeDescendants(for: item)
            episodes = loadedEpisodes
            errorMessage = nil
        } catch {
            if episodes.isEmpty {
                displayItem = item
            }
            errorMessage = "Couldn't update watch status."
        }
    }

    private func setEpisodeWatchStatus(_ isWatched: Bool) async {
        let loadedEpisodes: [MediaItem]

        if episodes.isEmpty {
            do {
                loadedEpisodes = try await episodeDescendants(for: item)
                episodes = loadedEpisodes
            } catch {
                errorMessage = "Couldn't update watch status."
                return
            }
        } else {
            loadedEpisodes = episodes
        }

        let targets = loadedEpisodes.filter {
            if isWatched {
                return !$0.isWatched
            }

            return $0.isWatched || ($0.progress ?? 0) > 0 || ($0.resumeOffsetMilliseconds ?? 0) > 0
        }

        let previousEpisodes = loadedEpisodes
        let previousDisplayItem = displayItem
        episodes = loadedEpisodes.map { $0.settingWatchStatus(isWatched) }
        displayItem = item.settingWatchStatus(isWatched)
        errorMessage = nil

        isUpdating = true
        defer { isUpdating = false }

        do {
            for episode in targets {
                guard let playbackID = episode.playbackID else { continue }
                try await model.setWatchStatus(for: playbackID, isWatched: isWatched)
            }
        } catch {
            episodes = previousEpisodes
            displayItem = previousDisplayItem
            errorMessage = "Couldn't update watch status."
        }
    }

    private func episodeDescendants(for item: MediaItem) async throws -> [MediaItem] {
        let children = try await model.loadChildren(for: item)
        var descendants: [MediaItem] = []

        for child in children {
            switch child.kind {
            case .episode:
                descendants.append(child)
            case .series, .season:
                descendants += try await episodeDescendants(for: child)
            case .movie, .other:
                continue
            }
        }

        return descendants
    }
}

private struct MediaWatchStatusMenu: View {
    let title: String
    let progress: Double?
    let isWatched: Bool
    let isUpdating: Bool
    let errorMessage: String?
    let onMarkWatched: () -> Void
    let onMarkUnwatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button("Mark Watched", action: onMarkWatched)

                Button("Mark Unwatched", action: onMarkUnwatched)
            } label: {
                Label(title, systemImage: MediaWatchStatusDisplay.iconName)
            }
            .buttonStyle(MediaGlassButtonStyle(tint: MediaWatchStatusDisplay.buttonColor(progress: progress, isWatched: isWatched)))
            .disabled(isUpdating)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

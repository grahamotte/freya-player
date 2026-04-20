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
        guard item.playbackID != nil else { return }
        let previousItem = item
        item = item.settingWatchStatus(isWatched)
        errorMessage = nil

        isUpdating = true
        defer { isUpdating = false }

        do {
            try await model.setWatchStatus(for: previousItem, isWatched: isWatched)
        } catch {
            item = previousItem
            errorMessage = "Couldn't update watch status."
        }
    }
}

struct MediaCollectionWatchStatusButton: View {
    @ObservedObject var model: AppModel
    private let item: MediaItem
    private let reloadID: String
    private let loadItems: () async throws -> [MediaItem]
    private let onUpdateFinished: (() async -> Void)?

    @State private var targets: [MediaItem] = []
    @State private var displayItem: MediaItem
    @State private var isLoading = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    init(
        model: AppModel,
        item: MediaItem,
        onUpdateFinished: (() async -> Void)? = nil
    ) {
        self.init(
            model: model,
            item: item,
            reloadID: item.id,
            loadItems: {
                try await model.watchStatusTargets(for: item)
            },
            onUpdateFinished: onUpdateFinished
        )
    }

    init(
        model: AppModel,
        item: MediaItem,
        reloadID: String,
        loadItems: @escaping () async throws -> [MediaItem],
        onUpdateFinished: (() async -> Void)? = nil
    ) {
        self.model = model
        self.item = item
        self.reloadID = reloadID
        self.loadItems = loadItems
        self.onUpdateFinished = onUpdateFinished
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
        .disabled(isUpdating)
        .task(id: reloadID) {
            await loadTargets()
        }
    }

    private func loadTargets() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedTargets = try await loadItems()
            targets = loadedTargets
            errorMessage = nil
        } catch {
            if targets.isEmpty {
                displayItem = item
            }
            errorMessage = "Couldn't update watch status."
        }
    }

    private func setEpisodeWatchStatus(_ isWatched: Bool) async {
        let loadedTargets: [MediaItem]

        if targets.isEmpty {
            do {
                loadedTargets = try await loadItems()
                targets = loadedTargets
            } catch {
                errorMessage = "Couldn't update watch status."
                return
            }
        } else {
            loadedTargets = targets
        }

        let updateTargets = loadedTargets.filter {
            if isWatched {
                return !$0.isWatched
            }

            return $0.isWatched || ($0.progress ?? 0) > 0 || ($0.resumeOffsetMilliseconds ?? 0) > 0
        }

        let previousTargets = loadedTargets
        let previousDisplayItem = displayItem
        targets = loadedTargets.map { $0.settingWatchStatus(isWatched) }
        displayItem = item.settingWatchStatus(isWatched)
        errorMessage = nil

        guard !updateTargets.isEmpty else {
            await onUpdateFinished?()
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        do {
            try await setWatchStatus(for: updateTargets, isWatched: isWatched)
            await onUpdateFinished?()
        } catch {
            targets = previousTargets
            displayItem = previousDisplayItem
            errorMessage = "Couldn't update watch status."
        }
    }

    private func setWatchStatus(for items: [MediaItem], isWatched: Bool) async throws {
        for item in items {
            guard let playbackID = item.playbackID else { continue }
            try await model.setWatchStatus(for: playbackID, isWatched: isWatched)
        }
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
                HStack(spacing: 10) {
                    if isUpdating {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Label(title, systemImage: MediaWatchStatusDisplay.iconName)
                }
            }
            .buttonStyle(MediaGlassButtonStyle(tint: MediaWatchStatusDisplay.buttonColor(progress: progress, isWatched: isWatched)))
            .fixedSize(horizontal: true, vertical: false)
            .disabled(isUpdating)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}

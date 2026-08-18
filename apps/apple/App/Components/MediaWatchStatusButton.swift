import SwiftUI

struct MediaWatchStatusButton: View {
    @ObservedObject var model: AppModel
    @ObservedObject var cache: LibraryCache
    let item: MediaItem

    init(model: AppModel, item: MediaItem) {
        self.model = model
        self.cache = model.libraryCache
        self.item = item
    }

    var body: some View {
        if item.playbackID != nil {
            let displayItem = cache.item(item.id) ?? item

            MediaWatchStatusMenu(
                title: MediaWatchStatusDisplay.title(progress: displayItem.progress, isWatched: displayItem.isWatched),
                progress: displayItem.progress,
                isWatched: displayItem.isWatched,
                onMarkWatched: { model.setWatchStatus(for: item, isWatched: true) },
                onMarkUnwatched: { model.setWatchStatus(for: item, isWatched: false) }
            )
        }
    }
}

struct MediaCollectionWatchStatusButton: View {
    @ObservedObject var model: AppModel
    @ObservedObject var cache: LibraryCache

    private let scope: Scope

    init(model: AppModel, item: MediaItem) {
        self.model = model
        self.cache = model.libraryCache
        self.scope = .item(item)
    }

    init(model: AppModel, libraryItem: MediaItem, libraryID: String) {
        self.model = model
        self.cache = model.libraryCache
        self.scope = .library(item: libraryItem, libraryID: libraryID)
    }

    var body: some View {
        let displayItem = currentDisplayItem()

        MediaWatchStatusMenu(
            title: MediaWatchStatusDisplay.title(progress: displayItem.progress, isWatched: displayItem.isWatched),
            progress: displayItem.progress,
            isWatched: displayItem.isWatched,
            onMarkWatched: { applyWatchStatus(true) },
            onMarkUnwatched: { applyWatchStatus(false) }
        )
    }

    private func currentDisplayItem() -> MediaItem {
        switch scope {
        case .item(let item):
            return cache.item(item.id) ?? cache.derivedItem(item)
        case .library(let item, let libraryID):
            return cache.derivedLibraryItem(item, libraryID: libraryID)
        }
    }

    private func applyWatchStatus(_ isWatched: Bool) {
        switch scope {
        case .item(let item):
            model.setWatchStatus(for: item, isWatched: isWatched)
        case .library(_, let libraryID):
            for item in cache.libraryItems(for: libraryID) {
                model.setWatchStatus(for: item, isWatched: isWatched)
            }
        }
    }

    private enum Scope {
        case item(MediaItem)
        case library(item: MediaItem, libraryID: String)
    }
}

private struct MediaWatchStatusMenu: View {
    let title: String
    let progress: Double?
    let isWatched: Bool
    let onMarkWatched: () -> Void
    let onMarkUnwatched: () -> Void

    var body: some View {
        Menu {
            Button(MediaWatchStatusDisplay.markSeenTitle, action: onMarkWatched)
            Button(MediaWatchStatusDisplay.markUnseenTitle, action: onMarkUnwatched)
        } label: {
            Label(title, systemImage: MediaWatchStatusDisplay.iconName)
        }
        .buttonStyle(MediaGlassButtonStyle(tint: MediaWatchStatusDisplay.buttonColor(progress: progress, isWatched: isWatched)))
        .fixedSize(horizontal: true, vertical: false)
    }
}

import SwiftUI

struct PlayableMediaItemView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var cache: LibraryCache
    let originalItem: MediaItem

    init(model: AppModel, item: MediaItem) {
        self.model = model
        self.cache = model.libraryCache
        self.originalItem = item
    }

    private var item: MediaItem {
        cache.item(originalItem.id) ?? originalItem
    }

    var body: some View {
        MediaView(model: model, data: item.mediaViewData()) {
            MediaItemActionRow {
                if let playbackID = item.playbackID {
                    MediaPlayButton(
                        model: model,
                        item: item,
                        id: playbackID,
                        onPlaybackDismissed: refreshItem
                    )
                }

                MediaWatchStatusButton(model: model, item: item)
            }
        }
        .task(id: originalItem.id) {
            refreshItem()
        }
    }

    private func refreshItem() {
        model.refreshItem(originalItem)
    }
}

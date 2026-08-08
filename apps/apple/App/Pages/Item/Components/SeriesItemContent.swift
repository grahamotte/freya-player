import SwiftUI

struct SeriesItemContent: View {
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
            VStack(alignment: .leading, spacing: 32) {
                MediaItemActionRow {
                    MediaPlayAllButton(model: model, items: playableItems)
                    MediaCollectionWatchStatusButton(model: model, item: item)
                }

                ItemChildListSection(
                    model: model,
                    item: item,
                    title: "Seasons",
                    emptyMessage: "No seasons yet.",
                    destination: { $0.route },
                    rowStyle: .standard,
                    autoFocusNextUnwatched: true
                )
            }
        }
        .task(id: originalItem.id) { model.refreshItem(originalItem) }
    }

    private var playableItems: [MediaItem] {
        cache.leaves(under: item.id).filter { !$0.isWatched }
    }
}

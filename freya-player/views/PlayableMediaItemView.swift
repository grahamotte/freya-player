import SwiftUI

struct PlayableMediaItemView: View {
    @ObservedObject var model: AppModel
    @State private var item: MediaItem

    init(model: AppModel, item: MediaItem) {
        self.model = model
        _item = State(initialValue: item)
    }

    var body: some View {
        MediaView(model: model, data: item.mediaViewData()) {
            MediaWatchStatusButton(model: model, item: $item)

            if let playbackID = item.playbackID {
                MediaPlayButton(
                    model: model,
                    id: playbackID,
                    hasResume: item.hasResume,
                    resumeOffsetMilliseconds: item.resumeOffsetMilliseconds,
                    onPlaybackDismissed: refreshItem
                )
            }
        }
        .task(id: item.id) {
            await refreshItem()
        }
    }

    private func refreshItem() async {
        do {
            item = try await model.loadItem(item)
        } catch {}
    }
}

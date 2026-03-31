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
        }
    }
}

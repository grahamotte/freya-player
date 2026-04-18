import SwiftUI

#if os(iOS)
struct TvEpisodeItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}
#endif

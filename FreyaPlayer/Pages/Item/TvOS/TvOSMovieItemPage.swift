import SwiftUI

#if os(tvOS)
struct MovieItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}
#endif

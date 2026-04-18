import SwiftUI

#if os(tvOS)
struct OtherItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}
#endif

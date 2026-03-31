import SwiftUI

struct ShowMovieView: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}

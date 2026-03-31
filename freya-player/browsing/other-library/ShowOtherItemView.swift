import SwiftUI

struct ShowOtherItemView: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        MediaView(model: model, data: item.mediaViewData())
    }
}

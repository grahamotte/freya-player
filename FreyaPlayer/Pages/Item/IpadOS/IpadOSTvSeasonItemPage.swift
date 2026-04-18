import SwiftUI

#if os(iOS)
struct TvSeasonItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        SeasonItemContent(model: model, item: item)
    }
}
#endif

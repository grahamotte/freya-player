import SwiftUI

#if os(tvOS)
struct TvSeriesItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        SeriesItemContent(model: model, item: item)
    }
}
#endif

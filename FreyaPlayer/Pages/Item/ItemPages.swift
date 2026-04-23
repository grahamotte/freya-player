import SwiftUI

struct MovieItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}

struct OtherItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}

struct TvEpisodeItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        PlayableMediaItemView(model: model, item: item)
    }
}

struct TvSeasonItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        SeasonItemContent(model: model, item: item)
    }
}

struct TvSeriesItemPage: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        SeriesItemContent(model: model, item: item)
    }
}

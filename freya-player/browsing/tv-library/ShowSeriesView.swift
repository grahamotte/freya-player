import SwiftUI

struct ShowSeriesView: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        MediaView(model: model, data: item.mediaViewData()) {
            TVChildListSection(
                model: model,
                item: item,
                title: "Seasons",
                emptyMessage: "No seasons yet.",
                destination: { $0.route },
                rowStyle: .standard
            )
        }
    }
}

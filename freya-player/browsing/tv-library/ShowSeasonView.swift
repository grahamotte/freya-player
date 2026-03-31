import SwiftUI

struct ShowSeasonView: View {
    @ObservedObject var model: AppModel
    let item: MediaItem

    var body: some View {
        MediaView(model: model, data: item.mediaViewData()) {
            TVChildListSection(
                model: model,
                item: item,
                title: "Episodes",
                emptyMessage: "No episodes yet.",
                destination: { $0.route },
                rowStyle: .numbered
            )
        }
    }
}

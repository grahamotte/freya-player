import SwiftUI

struct ShowSeasonView: View {
    @ObservedObject var model: AppModel
    let item: PlexMediaItem

    var body: some View {
        Group {
            if let summary = model.connectedSummary {
                MediaView(model: model, data: item.mediaViewData(in: summary)) {
                    TVChildListSection(
                        model: model,
                        item: item,
                        title: "Episodes",
                        emptyMessage: "No episodes yet."
                        ,
                        destination: { .episode($0) },
                        rowStyle: .numbered
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppBackground())
            }
        }
    }
}

import SwiftUI

struct ShowSeriesView: View {
    @ObservedObject var model: AppModel
    let item: PlexMediaItem

    var body: some View {
        Group {
            if let summary = model.connectedSummary {
                MediaView(model: model, data: item.mediaViewData(in: summary)) {
                    TVChildListSection(
                        model: model,
                        item: item,
                        title: "Seasons",
                        emptyMessage: "No seasons yet."
                        ,
                        destination: { .season($0) },
                        rowStyle: .standard
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

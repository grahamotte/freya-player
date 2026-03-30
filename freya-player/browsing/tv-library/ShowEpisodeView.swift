import SwiftUI

struct ShowEpisodeView: View {
    @ObservedObject var model: AppModel
    let item: PlexMediaItem

    var body: some View {
        Group {
            if let summary = model.connectedSummary {
                MediaView(
                    model: model,
                    data: item.mediaViewData(
                        in: summary,
                        playbackID: .plex(item.ratingKey)
                    )
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppBackground())
            }
        }
    }
}

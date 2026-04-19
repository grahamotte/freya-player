import SwiftUI

#if os(iOS)
struct LibrariesPage: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    private var visibleLibraries: [LibraryShelf] {
        server.libraries.filter { !$0.isHidden }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text(server.serverName)
                    .font(.largeTitle.weight(.bold))
                .padding(.horizontal, 32)

                ForEach(visibleLibraries) { shelf in
                    let previewItems = shelf.recentUnwatchedItems
                    let artworkStyle = shelf.reference.artworkStyle
                    let cardWidth: CGFloat = artworkStyle == .poster ? 180 : 280
                    VStack(alignment: .leading, spacing: 16) {
                        Text(shelf.title)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 32)

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                NavigationLink(value: shelf.reference.route) {
                                    OpenLibraryCard(title: shelf.title, artworkStyle: artworkStyle)
                                        .frame(width: cardWidth)
                                }
                                .buttonStyle(.plain)

                                ForEach(previewItems) { item in
                                    NavigationLink(value: item.route) {
                                        LibraryItemCard(item: item, artworkStyle: artworkStyle)
                                            .frame(width: cardWidth)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 32)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(LibrariesAmbientBackground())
        .toolbar {
            Button("Settings") {
                path.append(server.providerID.settingsRoute)
            }
        }
        .task(id: server.id) {
            await PollingLoop.run {
                await model.refreshConnection()
            }
        }
    }
}

private struct OpenLibraryCard: View {
    let title: String
    let artworkStyle: MediaArtworkStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceFill)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.semibold))

                        Text("Open Library")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(18)
                }
                .aspectRatio(artworkStyle.aspectRatio, contentMode: .fit)

            Text(title)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

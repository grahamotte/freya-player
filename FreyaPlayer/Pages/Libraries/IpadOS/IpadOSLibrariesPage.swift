import SwiftUI

#if os(iOS)
struct LibrariesPage: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    private var projection: LibrariesHomeProjection {
        LibrariesHomeProjection(server: server)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text(projection.serverName)
                    .font(.largeTitle.weight(.bold))
                .padding(.horizontal, 32)

                ForEach(projection.shelves) { shelf in
                    let artworkStyle = shelf.artworkStyle
                    let cardWidth: CGFloat = artworkStyle == .poster ? 180 : 280
                    VStack(alignment: .leading, spacing: 16) {
                        Text(shelf.title)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 32)

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                NavigationLink(value: shelf.libraryRoute) {
                                    OpenLibraryCard(artworkStyle: artworkStyle)
                                        .frame(width: cardWidth)
                                }
                                .buttonStyle(.plain)

                                ForEach(shelf.previewItems) { item in
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
            Button("Manage") {
                path.append(projection.manageRoute)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

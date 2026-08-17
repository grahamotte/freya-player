import SwiftUI

struct LibrariesPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var cache: LibraryCache
    @State private var isRefreshing: Bool
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    private var pagePadding: CGFloat { PlatformMetadata.isPhone ? 16 : 32 }
    private var sectionSpacing: CGFloat { PlatformMetadata.isPhone ? 20 : 32 }
    private var shelfSpacing: CGFloat { PlatformMetadata.isPhone ? 12 : 16 }
    private var cardSpacing: CGFloat { PlatformMetadata.isPhone ? 10 : 16 }

    init(model: AppModel, server: ConnectedServer, path: Binding<[AppRoute]>) {
        self.model = model
        self.cache = model.libraryCache
        _isRefreshing = State(initialValue: model.isRefreshingAllLibraries(server))
        self.server = server
        _path = path
    }

    private var projection: LibrariesHomeProjection {
        LibrariesHomeProjection(server: server, cache: cache)
    }

    var body: some View {
        PlatformLibrariesPageContent(model: model, server: server, path: $path, iOSLayout: AnyView(iOSLayout))
    }

    private var iOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text(projection.serverName)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, pagePadding)

                ForEach(projection.shelves) { shelf in
                    let artworkStyle = shelf.artworkStyle
                    let cardWidth: CGFloat = artworkStyle == .poster ? (PlatformMetadata.isPhone ? 130 : 180) : (PlatformMetadata.isPhone ? 200 : 280)
                    VStack(alignment: .leading, spacing: shelfSpacing) {
                        Text(shelf.title)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, pagePadding)

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: cardSpacing) {
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
                                    .mediaItemQuickActions(model: model, item: item)
                                }
                            }
                            .padding(.horizontal, pagePadding)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        model.refreshAllLibraries(server)
                    } label: {
                        if isRefreshing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Refreshing...")
                            }
                        } else {
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                    .disabled(isRefreshing)

                    NavigationLink(value: projection.manageRoute) {
                        Text("Manage")
                    }
                    .buttonStyle(MediaGlassButtonStyle())

                    NavigationLink(value: AppRoute.about) {
                        Text("About")
                    }
                    .buttonStyle(MediaGlassButtonStyle())
                }
                .padding(.horizontal, pagePadding)
                .padding(.top, 8)
                .padding(.bottom, pagePadding)
            }
        }
        .scrollIndicators(.hidden)
        .background(LibrariesAmbientBackground())
        .onReceive(model.refreshTracker.$inFlight) { _ in
            let nextIsRefreshing = model.isRefreshingAllLibraries(server)
            guard isRefreshing != nextIsRefreshing else { return }
            isRefreshing = nextIsRefreshing
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

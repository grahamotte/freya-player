import SwiftUI

struct LibrariesView: View {
    let summary: PlexConnectionSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text(summary.serverName)
                    .font(.largeTitle.weight(.semibold))

                ForEach(summary.libraries) { library in
                    PlexLibraryShelfView(library: library, summary: summary)
                }

                NavigationLink(value: AppRoute.plexSettings) {
                    Text("Manage Server")
                        .frame(minWidth: 260)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 12)
                .focusSection()
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }
}

private struct PlexLibraryShelfView: View {
    let library: PlexLibrarySection
    let summary: PlexConnectionSummary
    @FocusState private var focusedItemID: String?

    private var shelfStyle: PlexShelfStyle {
        switch library.type {
        case "movie", "show":
            return .poster
        default:
            return .wide
        }
    }

    private var selectedItem: PlexMediaItem? {
        library.items.first(where: { $0.id == focusedItemID }) ?? library.items.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(library.title)
                    .font(.title3.weight(.semibold))

                Spacer()

                NavigationLink("Open Library", value: library.indexRoute)
                    .buttonStyle(.bordered)
            }

            if library.items.isEmpty {
                Text("No recent items yet.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 40) {
                        ForEach(library.items) { item in
                            NavigationLink(value: library.itemRoute(for: item)) {
                                PlexArtworkView(
                                    url: item.artworkURL(
                                        baseURL: summary.serverURL,
                                        token: summary.serverToken,
                                        width: shelfStyle.imageSize.width,
                                        height: shelfStyle.imageSize.height,
                                        preferCoverArt: shelfStyle == .wide
                                    ),
                                    aspectRatio: shelfStyle.aspectRatio
                                )
                                .containerRelativeFrame(.horizontal, count: shelfStyle.columns, spacing: 40)
                            }
                            .focused($focusedItemID, equals: item.id)
                            .accessibilityLabel(item.title)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
                .buttonStyle(.borderless)

                Text(selectedItem?.title ?? "")
                    .font(.body)
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 48, alignment: .topLeading)
            }
        }
        .focusSection()
    }
}

private struct PlexArtworkView: View {
    let url: URL?
    let aspectRatio: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}

private enum PlexShelfStyle: Equatable {
    case poster
    case wide

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .wide:
            return 16 / 9
        }
    }

    var columns: Int {
        switch self {
        case .poster:
            return 6
        case .wide:
            return 8
        }
    }

    var imageSize: (width: Int, height: Int) {
        switch self {
        case .poster:
            return (480, 720)
        case .wide:
            return (640, 360)
        }
    }
}

private extension PlexLibrarySection {
    var indexRoute: AppRoute {
        switch type {
        case "movie":
            return .movieLibrary(title)
        case "show":
            return .tvLibrary(title)
        default:
            return .otherLibrary(title)
        }
    }

    func itemRoute(for item: PlexMediaItem) -> AppRoute {
        switch type {
        case "movie":
            return .movie(item.title)
        case "show":
            return .series(item.title)
        default:
            return .other(item.title)
        }
    }
}

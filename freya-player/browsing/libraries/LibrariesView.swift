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
    @FocusState private var focusedTileID: String?

    private var openTileID: String { "\(library.id)-open" }

    private var shelfStyle: PlexShelfStyle {
        switch library.type {
        case "movie", "show":
            return .poster
        default:
            return .wide
        }
    }

    private var selectedLabel: String {
        if focusedTileID == openTileID {
            return library.title
        }

        return library.items.first(where: { $0.id == focusedTileID })?.title ?? library.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(library.title)
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    NavigationLink(value: library.indexRoute) {
                        PlexTilePlaceholderView(
                            title: library.title,
                            iconName: "arrow.right",
                            aspectRatio: shelfStyle.aspectRatio
                        )
                        .containerRelativeFrame(.horizontal, count: shelfStyle.columns, spacing: 40)
                    }
                    .focused($focusedTileID, equals: openTileID)

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
                                title: item.title,
                                iconName: shelfStyle.placeholderIconName,
                                aspectRatio: shelfStyle.aspectRatio
                            )
                            .containerRelativeFrame(.horizontal, count: shelfStyle.columns, spacing: 40)
                        }
                        .focused($focusedTileID, equals: item.id)
                        .accessibilityLabel(item.title)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()
            .buttonStyle(.card)

            if library.items.isEmpty {
                Text("No recent items yet.")
                    .font(.body)
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 48, alignment: .topLeading)
            } else {
                Text(selectedLabel)
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
    let title: String
    let iconName: String
    let aspectRatio: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
            default:
                PlexTilePlaceholderView(
                    title: title,
                    iconName: iconName,
                    aspectRatio: aspectRatio
                )
            }
        }
    }
}

private struct PlexTilePlaceholderView: View {
    let title: String
    let iconName: String
    let aspectRatio: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        ZStack {
            shape
                .fill(Color.white.opacity(0.08))

            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 44, weight: .semibold))

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(.secondary)
            .padding(24)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(shape)
        .contentShape(shape)
        .compositingGroup()
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

    var placeholderIconName: String {
        switch self {
        case .poster:
            return "film.stack.fill"
        case .wide:
            return "tv.fill"
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
            return .movie(item)
        case "show":
            return .series(item)
        default:
            return .other(item.title)
        }
    }
}

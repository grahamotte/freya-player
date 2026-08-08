import Foundation

@MainActor
struct LibrariesHomeProjection {
    let serverName: String
    let manageRoute: AppRoute
    let shelves: [Shelf]

    init(server: ConnectedServer, cache: LibraryCache? = nil) {
        serverName = server.serverName
        manageRoute = server.providerID.settingsRoute
        shelves = server.libraries.filter { !$0.isHidden }.map { library in
            let cachedItems = cache?.libraryItems(for: library.id) ?? library.items
            let items = cachedItems.map { cache?.derivedItem($0) ?? $0 }
            return Shelf(
                id: library.id,
                title: library.title,
                artworkStyle: library.reference.artworkStyle,
                libraryRoute: library.reference.route,
                previewItems: library.recentUnwatchedItems(from: items)
            )
        }
    }

    struct Shelf: Identifiable {
        let id: String
        let title: String
        let artworkStyle: MediaArtworkStyle
        let libraryRoute: AppRoute
        let previewItems: [MediaItem]

        var emptyMessage: String? {
            previewItems.isEmpty ? "No recent items yet." : nil
        }
    }
}

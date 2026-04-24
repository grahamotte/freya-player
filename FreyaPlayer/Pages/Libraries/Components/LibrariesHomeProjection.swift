import Foundation

struct LibrariesHomeProjection {
    let serverName: String
    let manageRoute: AppRoute
    let shelves: [Shelf]

    init(
        server: ConnectedServer,
        itemTransform: (MediaItem) -> MediaItem = { $0 }
    ) {
        serverName = server.serverName
        manageRoute = server.providerID.settingsRoute
        shelves = server.libraries.filter { !$0.isHidden }.map { library in
            let items = library.items.map(itemTransform)
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

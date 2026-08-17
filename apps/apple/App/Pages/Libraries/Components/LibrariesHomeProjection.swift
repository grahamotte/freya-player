import Foundation

@MainActor
struct LibrariesHomeProjection {
    let serverName: String
    let manageRoute: AppRoute
    let shelves: [Shelf]

    init(
        server: ConnectedServer,
        cache: LibraryCache? = nil
    ) {
        self.init(server: server, cache: cache, store: MediaSessionStore())
    }

    init(
        server: ConnectedServer,
        cache: LibraryCache?,
        store: MediaSessionStore
    ) {
        serverName = server.serverName
        manageRoute = server.providerID.settingsRoute
        shelves = server.libraries.filter { !$0.isHidden }.map { library in
            let cachedItems = cache?.libraryItems(for: library.id) ?? library.items
            let items = cachedItems.map { cache?.derivedItem($0) ?? $0 }
            let filter = store.libraryFilter(for: library.reference)
            let sort = store.librarySort(for: library.reference)
            let order = store.librarySortOrder(for: library.reference, sort: sort)
            return Shelf(
                id: library.id,
                title: library.title,
                artworkStyle: library.reference.artworkStyle,
                libraryRoute: library.reference.route,
                previewItems: library.previewItems(
                    from: items,
                    filter: filter,
                    sort: sort,
                    order: order
                ),
                emptyStateText: filter.emptyStateText(for: library.reference.itemTitle)
            )
        }
    }

    struct Shelf: Identifiable {
        let id: String
        let title: String
        let artworkStyle: MediaArtworkStyle
        let libraryRoute: AppRoute
        let previewItems: [MediaItem]
        let emptyStateText: String

        var emptyMessage: String? {
            previewItems.isEmpty ? emptyStateText : nil
        }
    }
}

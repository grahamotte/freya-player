import Foundation

struct LibraryShelf: Hashable, Identifiable, Codable {
    let id: String
    let title: String
    let reference: LibraryReference
    let items: [MediaItem]
    let isHidden: Bool

    func settingHidden(_ isHidden: Bool) -> LibraryShelf {
        LibraryShelf(
            id: id,
            title: title,
            reference: reference,
            items: items,
            isHidden: isHidden
        )
    }

    func settingItems(_ items: [MediaItem]) -> LibraryShelf {
        LibraryShelf(
            id: id,
            title: title,
            reference: reference,
            items: items,
            isHidden: isHidden
        )
    }

    func previewItems(
        from items: [MediaItem],
        filter: LibraryPageFilter,
        sort: LibraryPageSort,
        order: LibraryPageSortOrder
    ) -> [MediaItem] {
        Array(
            sort.items(
                from: items.filter { filter.matches($0) },
                order: order
            )
                .prefix(20)
        )
    }
}

struct LibraryReference: Hashable, Identifiable, Codable {
    let providerID: MediaProviderID
    let serverID: String
    let id: String
    let title: String
    let itemTitle: String
    let artworkStyle: MediaArtworkStyle
    let defaultItemKind: MediaItemKind

    func watchStatusItem(from items: [MediaItem]) -> MediaItem? {
        guard !items.isEmpty else { return nil }

        let progress = items.reduce(0.0) { partial, item in
            partial + (item.isWatched ? 1 : min(max(item.progress ?? 0, 0), 1))
        } / Double(items.count)
        let isWatched = items.allSatisfy(\.isWatched)

        return MediaItem(
            providerID: providerID,
            serverID: serverID,
            id: "library:\(id)",
            title: title,
            kind: defaultItemKind,
            synopsis: "",
            addedAt: nil,
            releasedAt: nil,
            year: nil,
            durationMilliseconds: nil,
            contentRating: nil,
            tmdbID: nil,
            isWatched: isWatched,
            progress: isWatched ? 1 : (progress > 0 ? progress : nil),
            resumeOffsetMilliseconds: nil,
            artwork: .init(posterURL: nil, thumbnailURL: nil, landscapeURL: nil, backdropURL: nil),
            detailSections: nil
        )
    }

    func watchStatusReloadID(from items: [MediaItem]) -> String {
        items.map {
            "\($0.id):\($0.isWatched):\($0.progress ?? 0):\($0.resumeOffsetMilliseconds ?? 0)"
        }.joined(separator: ",")
    }
}

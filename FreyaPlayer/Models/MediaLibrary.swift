import Foundation

struct LibraryShelf: Hashable, Identifiable {
    let id: String
    let title: String
    let reference: LibraryReference
    let items: [MediaItem]
    let isHidden: Bool

    var recentUnwatchedItems: [MediaItem] {
        recentUnwatchedItems(from: items)
    }

    func settingHidden(_ isHidden: Bool) -> LibraryShelf {
        LibraryShelf(
            id: id,
            title: title,
            reference: reference,
            items: items,
            isHidden: isHidden
        )
    }

    func recentUnwatchedItems(from items: [MediaItem]) -> [MediaItem] {
        Array(
            items
                .filter { !$0.isWatched }
                .sorted { ($0.addedAt ?? .min) > ($1.addedAt ?? .min) }
                .prefix(20)
        )
    }
}

struct LibraryReference: Hashable, Identifiable {
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
            year: nil,
            durationMilliseconds: nil,
            contentRating: nil,
            isWatched: isWatched,
            progress: isWatched ? 1 : (progress > 0 ? progress : nil),
            resumeOffsetMilliseconds: nil,
            artwork: .init(posterURL: nil, landscapeURL: nil, backdropURL: nil)
        )
    }

    func watchStatusReloadID(from items: [MediaItem]) -> String {
        items.map {
            "\($0.id):\($0.isWatched):\($0.progress ?? 0):\($0.resumeOffsetMilliseconds ?? 0)"
        }.joined(separator: ",")
    }
}

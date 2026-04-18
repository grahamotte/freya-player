import Foundation

struct LibraryShelf: Hashable, Identifiable {
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
}

struct LibraryReference: Hashable, Identifiable {
    let providerID: MediaProviderID
    let serverID: String
    let id: String
    let title: String
    let itemTitle: String
    let artworkStyle: MediaArtworkStyle
    let defaultItemKind: MediaItemKind
}

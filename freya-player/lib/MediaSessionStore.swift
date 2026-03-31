import Foundation

final class MediaSessionStore {
    private let defaults = UserDefaults.standard
    private let libraryFilterKeyPrefix = "media.library.filter"
    private let librarySortKeyPrefix = "media.library.sort"
    private let librarySortOrderKeyPrefix = "media.library.sort.order"

    func libraryFilterRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: libraryFilterKeyPrefix, library: library)) as? Int
    }

    func setLibraryFilterRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: libraryFilterKeyPrefix, library: library))
    }

    func librarySortRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: librarySortKeyPrefix, library: library)) as? Int
    }

    func setLibrarySortRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: librarySortKeyPrefix, library: library))
    }

    func librarySortOrderRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: librarySortOrderKeyPrefix, library: library)) as? Int
    }

    func setLibrarySortOrderRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: librarySortOrderKeyPrefix, library: library))
    }

    private func key(prefix: String, library: LibraryReference) -> String {
        "\(prefix).\(library.providerID.rawValue).\(library.serverID).\(library.id)"
    }
}

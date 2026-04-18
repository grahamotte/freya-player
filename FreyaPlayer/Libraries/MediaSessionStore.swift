import Foundation

protocol DefaultsStore {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func stringArray(forKey defaultName: String) -> [String]?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: DefaultsStore {}

final class MediaSessionStore {
    private let defaults: any DefaultsStore
    private let libraryFilterKeyPrefix = "media.library.filter"
    private let librarySortKeyPrefix = "media.library.sort"
    private let librarySortOrderKeyPrefix = "media.library.sort.order"
    private let libraryOrderKeyPrefix = "media.server.library.order"
    private let hiddenLibrariesKeyPrefix = "media.server.library.hidden"

    init(defaults: any DefaultsStore = UserDefaults.standard) {
        self.defaults = defaults
    }

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

    func libraryOrder(providerID: MediaProviderID, serverID: String) -> [String] {
        defaults.stringArray(forKey: key(prefix: libraryOrderKeyPrefix, providerID: providerID, serverID: serverID)) ?? []
    }

    func setLibraryOrder(_ libraryIDs: [String], providerID: MediaProviderID, serverID: String) {
        defaults.set(libraryIDs, forKey: key(prefix: libraryOrderKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func hiddenLibraryIDs(providerID: MediaProviderID, serverID: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key(prefix: hiddenLibrariesKeyPrefix, providerID: providerID, serverID: serverID)) ?? [])
    }

    func setHiddenLibraryIDs(_ libraryIDs: Set<String>, providerID: MediaProviderID, serverID: String) {
        defaults.set(Array(libraryIDs), forKey: key(prefix: hiddenLibrariesKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func clearLibraryManagement(providerID: MediaProviderID, serverID: String) {
        defaults.removeObject(forKey: key(prefix: libraryOrderKeyPrefix, providerID: providerID, serverID: serverID))
        defaults.removeObject(forKey: key(prefix: hiddenLibrariesKeyPrefix, providerID: providerID, serverID: serverID))
    }

    private func key(prefix: String, library: LibraryReference) -> String {
        "\(prefix).\(library.providerID.rawValue).\(library.serverID).\(library.id)"
    }

    private func key(prefix: String, providerID: MediaProviderID, serverID: String) -> String {
        "\(prefix).\(providerID.rawValue).\(serverID)"
    }
}

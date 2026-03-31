import Foundation

final class PlexSessionStore {
    private let defaults = UserDefaults.standard
    private let tokenKey = "plex.user.token"
    private let serverKey = "plex.server.identifier"
    private let libraryFilterKeyPrefix = "plex.library.filter"
    private let librarySortKeyPrefix = "plex.library.sort"
    private let librarySortOrderKeyPrefix = "plex.library.sort.order"

    var userToken: String? {
        get { KeychainStore.value(for: tokenKey) }
        set {
            if let newValue {
                KeychainStore.setValue(newValue, for: tokenKey)
            } else {
                KeychainStore.removeValue(for: tokenKey)
            }
        }
    }

    var serverIdentifier: String? {
        get { defaults.string(forKey: serverKey) }
        set { defaults.set(newValue, forKey: serverKey) }
    }

    func libraryFilterRawValue(forLibraryID libraryID: String, serverID: String) -> Int? {
        let key = "\(libraryFilterKeyPrefix).\(serverID).\(libraryID)"
        return defaults.object(forKey: key) as? Int
    }

    func setLibraryFilterRawValue(_ rawValue: Int, forLibraryID libraryID: String, serverID: String) {
        let key = "\(libraryFilterKeyPrefix).\(serverID).\(libraryID)"
        defaults.set(rawValue, forKey: key)
    }

    func librarySortRawValue(forLibraryID libraryID: String, serverID: String) -> Int? {
        let key = "\(librarySortKeyPrefix).\(serverID).\(libraryID)"
        return defaults.object(forKey: key) as? Int
    }

    func setLibrarySortRawValue(_ rawValue: Int, forLibraryID libraryID: String, serverID: String) {
        let key = "\(librarySortKeyPrefix).\(serverID).\(libraryID)"
        defaults.set(rawValue, forKey: key)
    }

    func librarySortOrderRawValue(forLibraryID libraryID: String, serverID: String) -> Int? {
        let key = "\(librarySortOrderKeyPrefix).\(serverID).\(libraryID)"
        return defaults.object(forKey: key) as? Int
    }

    func setLibrarySortOrderRawValue(_ rawValue: Int, forLibraryID libraryID: String, serverID: String) {
        let key = "\(librarySortOrderKeyPrefix).\(serverID).\(libraryID)"
        defaults.set(rawValue, forKey: key)
    }

    func clear() {
        userToken = nil
        defaults.removeObject(forKey: serverKey)
    }
}

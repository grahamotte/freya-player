import Foundation

final class PlexSessionStore {
    private let defaults: any DefaultsStore
    private let tokenKey = "plex.user.token"
    private let serverKey = "plex.server.identifier"
    private let libraryFilterKeyPrefix = "plex.library.filter"
    private let librarySortKeyPrefix = "plex.library.sort"
    private let librarySortOrderKeyPrefix = "plex.library.sort.order"
    private let loadSecureValue: @MainActor (String) -> String?
    private let saveSecureValue: @MainActor (String, String) -> Void
    private let removeSecureValue: @MainActor (String) -> Void

    convenience init() {
        self.init(
            defaults: UserDefaults.standard,
            loadSecureValue: { KeychainStore.value(for: $0) },
            saveSecureValue: { KeychainStore.setValue($0, for: $1) },
            removeSecureValue: { KeychainStore.removeValue(for: $0) }
        )
    }

    init(
        defaults: any DefaultsStore,
        loadSecureValue: @escaping @MainActor (String) -> String?,
        saveSecureValue: @escaping @MainActor (String, String) -> Void,
        removeSecureValue: @escaping @MainActor (String) -> Void
    ) {
        self.defaults = defaults
        self.loadSecureValue = loadSecureValue
        self.saveSecureValue = saveSecureValue
        self.removeSecureValue = removeSecureValue
    }

    var userToken: String? {
        get { loadSecureValue(tokenKey) }
        set {
            if let newValue {
                saveSecureValue(newValue, tokenKey)
            } else {
                removeSecureValue(tokenKey)
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

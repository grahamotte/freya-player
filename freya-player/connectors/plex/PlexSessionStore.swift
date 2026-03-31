import Foundation
import Security

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

private enum KeychainStore {
    private static let service = "ottecode.FreyaPlayer"

    static func value(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func setValue(_ value: String, for key: String) {
        removeValue(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

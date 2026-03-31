import Foundation

final class JellyfinSessionStore {
    private let defaults = UserDefaults.standard
    private let serverURLKey = "jellyfin.server.url"
    private let userIDKey = "jellyfin.user.id"
    private let userNameKey = "jellyfin.user.name"
    private let tokenKey = "jellyfin.access.token"

    var serverURL: String? {
        get { defaults.string(forKey: serverURLKey) }
        set { defaults.set(newValue, forKey: serverURLKey) }
    }

    var userID: String? {
        get { defaults.string(forKey: userIDKey) }
        set { defaults.set(newValue, forKey: userIDKey) }
    }

    var userName: String? {
        get { defaults.string(forKey: userNameKey) }
        set { defaults.set(newValue, forKey: userNameKey) }
    }

    var accessToken: String? {
        get { KeychainStore.value(for: tokenKey) }
        set {
            if let newValue {
                KeychainStore.setValue(newValue, for: tokenKey)
            } else {
                KeychainStore.removeValue(for: tokenKey)
            }
        }
    }

    var hasSavedConnection: Bool {
        serverURL != nil && userID != nil && accessToken != nil
    }

    func clear() {
        defaults.removeObject(forKey: serverURLKey)
        defaults.removeObject(forKey: userIDKey)
        defaults.removeObject(forKey: userNameKey)
        accessToken = nil
    }
}

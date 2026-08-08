import Foundation
import Security

enum KeychainStore {
    private static let service = "ottecode.FreyaPlayer"
    private static let fallbackPrefix = "keychain.fallback"
    private static let removedPrefix = "keychain.removed"

    static func value(for key: String) -> String? {
        guard !UserDefaults.standard.bool(forKey: removedKey(for: key)) else { return nil }

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
            return UserDefaults.standard.string(forKey: fallbackKey(for: key))
        }

        return String(data: data, encoding: .utf8)
    }

    static func setValue(_ value: String, for key: String) {
        removeValue(for: key)
        UserDefaults.standard.set(false, forKey: removedKey(for: key))

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        if SecItemAdd(query as CFDictionary, nil) != errSecSuccess {
            UserDefaults.standard.set(value, forKey: fallbackKey(for: key))
        } else {
            UserDefaults.standard.removeObject(forKey: fallbackKey(for: key))
        }
    }

    static func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: key))
        UserDefaults.standard.set(true, forKey: removedKey(for: key))
    }

    private static func fallbackKey(for key: String) -> String {
        "\(fallbackPrefix).\(key)"
    }

    private static func removedKey(for key: String) -> String {
        "\(removedPrefix).\(key)"
    }
}

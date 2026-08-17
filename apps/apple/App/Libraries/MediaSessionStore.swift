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
    private let defaultLibraryFilterKeyPrefix = "media.server.library.filter.default"
    private let defaultLibrarySortKeyPrefix = "media.server.library.sort.default"
    private let defaultLibrarySortOrderKeyPrefix = "media.server.library.sort.order.default"
    private let libraryOrderKeyPrefix = "media.server.library.order"
    private let hiddenLibrariesKeyPrefix = "media.server.library.hidden"
    private let playbackSettingsKeyPrefix = "media.playback.settings"

    init(defaults: any DefaultsStore = UserDefaults.standard) {
        self.defaults = defaults
    }

    func libraryFilterRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: libraryFilterKeyPrefix, library: library)) as? Int
    }

    func setLibraryFilterRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: libraryFilterKeyPrefix, library: library))
    }

    func clearLibraryFilterRawValue(for library: LibraryReference) {
        defaults.removeObject(forKey: key(prefix: libraryFilterKeyPrefix, library: library))
    }

    func librarySortRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: librarySortKeyPrefix, library: library)) as? Int
    }

    func setLibrarySortRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: librarySortKeyPrefix, library: library))
    }

    func clearLibrarySortRawValue(for library: LibraryReference) {
        defaults.removeObject(forKey: key(prefix: librarySortKeyPrefix, library: library))
    }

    func librarySortOrderRawValue(for library: LibraryReference) -> Int? {
        defaults.object(forKey: key(prefix: librarySortOrderKeyPrefix, library: library)) as? Int
    }

    func setLibrarySortOrderRawValue(_ rawValue: Int, for library: LibraryReference) {
        defaults.set(rawValue, forKey: key(prefix: librarySortOrderKeyPrefix, library: library))
    }

    func clearLibrarySortOrderRawValue(for library: LibraryReference) {
        defaults.removeObject(forKey: key(prefix: librarySortOrderKeyPrefix, library: library))
    }

    func defaultLibraryFilterRawValue(providerID: MediaProviderID, serverID: String) -> Int? {
        defaults.object(forKey: key(prefix: defaultLibraryFilterKeyPrefix, providerID: providerID, serverID: serverID)) as? Int
    }

    func setDefaultLibraryFilterRawValue(_ rawValue: Int, providerID: MediaProviderID, serverID: String) {
        defaults.set(rawValue, forKey: key(prefix: defaultLibraryFilterKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func clearDefaultLibraryFilterRawValue(providerID: MediaProviderID, serverID: String) {
        defaults.removeObject(forKey: key(prefix: defaultLibraryFilterKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func defaultLibrarySortRawValue(providerID: MediaProviderID, serverID: String) -> Int? {
        defaults.object(forKey: key(prefix: defaultLibrarySortKeyPrefix, providerID: providerID, serverID: serverID)) as? Int
    }

    func setDefaultLibrarySortRawValue(_ rawValue: Int, providerID: MediaProviderID, serverID: String) {
        defaults.set(rawValue, forKey: key(prefix: defaultLibrarySortKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func clearDefaultLibrarySortRawValue(providerID: MediaProviderID, serverID: String) {
        defaults.removeObject(forKey: key(prefix: defaultLibrarySortKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func defaultLibrarySortOrderRawValue(providerID: MediaProviderID, serverID: String) -> Int? {
        defaults.object(forKey: key(prefix: defaultLibrarySortOrderKeyPrefix, providerID: providerID, serverID: serverID)) as? Int
    }

    func setDefaultLibrarySortOrderRawValue(_ rawValue: Int, providerID: MediaProviderID, serverID: String) {
        defaults.set(rawValue, forKey: key(prefix: defaultLibrarySortOrderKeyPrefix, providerID: providerID, serverID: serverID))
    }

    func clearDefaultLibrarySortOrderRawValue(providerID: MediaProviderID, serverID: String) {
        defaults.removeObject(forKey: key(prefix: defaultLibrarySortOrderKeyPrefix, providerID: providerID, serverID: serverID))
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

    func playbackSettings(for id: MediaPlaybackID, serverID: String) -> MediaPlaybackSettings? {
        guard let data = defaults.object(
            forKey: key(prefix: playbackSettingsKeyPrefix, id: id, serverID: serverID)
        ) as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(MediaPlaybackSettings.self, from: data)
    }

    func setPlaybackSettings(_ settings: MediaPlaybackSettings, for id: MediaPlaybackID, serverID: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key(prefix: playbackSettingsKeyPrefix, id: id, serverID: serverID))
    }

    private func key(prefix: String, library: LibraryReference) -> String {
        "\(prefix).\(library.providerID.rawValue).\(library.serverID).\(library.id)"
    }

    private func key(prefix: String, providerID: MediaProviderID, serverID: String) -> String {
        "\(prefix).\(providerID.rawValue).\(serverID)"
    }

    private func key(prefix: String, id: MediaPlaybackID, serverID: String) -> String {
        "\(prefix).\(id.providerID.rawValue).\(serverID).\(id.itemID)"
    }
}

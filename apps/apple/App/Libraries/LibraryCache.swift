import Foundation
import Combine

/// In-memory + on-disk cache of library content for the connected server.
///
/// The cache is the source of truth that views read from. Connectors only
/// feed the cache (via `ingest` and `refresh` methods on the AppModel side).
/// All non-leaf items (series, season, library) have their `isWatched` and
/// `progress` derived from the leaves currently stored in the cache so what
/// the user sees on screen always reflects the rolled-up watch counts of the
/// episodes/movies that we'd actually show pages for.
@MainActor
final class LibraryCache: ObservableObject {
    @Published private(set) var snapshot: LibraryCacheSnapshot
    @Published private(set) var storageSizeBytes: Int64

    private let storage: LibraryCacheStorage
    private var pendingSave: Task<Void, Never>?
    private let snapshotDidChangeSubject = PassthroughSubject<LibraryCacheSnapshot, Never>()

    var snapshotDidChange: AnyPublisher<LibraryCacheSnapshot, Never> {
        snapshotDidChangeSubject.eraseToAnyPublisher()
    }

    init(storage: LibraryCacheStorage) {
        self.storage = storage
        self.snapshot = storage.load() ?? LibraryCacheSnapshot()
        self.storageSizeBytes = storage.sizeBytes()
    }

    var formattedStorageSize: String {
        Self.formattedStorageSize(bytes: snapshot.isEmpty ? 0 : storageSizeBytes)
    }

    // MARK: - Server lifecycle

    func install(server: ConnectedServer) {
        let key = Self.serverKey(providerID: server.providerID, serverID: server.serverID)
        var next = snapshot.serverKey == key ? snapshot : LibraryCacheSnapshot(serverKey: key)

        next.serverKey = key

        var nextLibraries: [String: CachedLibrary] = [:]
        var libraryOrder: [String] = []

        for shelf in server.libraries {
            nextLibraries[shelf.id] = CachedLibrary(reference: shelf.reference, isHidden: shelf.isHidden)
            libraryOrder.append(shelf.id)

            next.libraryItemIDs[shelf.id] = shelf.items.map(\.id)
            for item in shelf.items {
                next.itemsByID[item.id] = item
            }
        }

        next.libraries = nextLibraries
        next.libraryOrder = libraryOrder
        next.libraryItemIDs = next.libraryItemIDs.filter { nextLibraries[$0.key] != nil }
        snapshot = next
        snapshotDidChangeSubject.send(snapshot)

        scheduleSave()
    }

    func clear() {
        pendingSave?.cancel()
        snapshot = LibraryCacheSnapshot()
        storage.clear()
        storageSizeBytes = storage.sizeBytes()
        snapshotDidChangeSubject.send(snapshot)
    }

    // MARK: - Reads

    func libraries() -> [CachedLibrary] {
        snapshot.libraryOrder.compactMap { snapshot.libraries[$0] }
    }

    func libraryItems(for libraryID: String) -> [MediaItem] {
        let ids = snapshot.libraryItemIDs[libraryID] ?? []
        return ids.compactMap { snapshot.itemsByID[$0] }.map(derivedItem(_:))
    }

    func children(of itemID: String) -> [MediaItem] {
        let ids = snapshot.childItemIDs[itemID] ?? []
        return ids.compactMap { snapshot.itemsByID[$0] }.map(derivedItem(_:))
    }

    func item(_ itemID: String) -> MediaItem? {
        snapshot.itemsByID[itemID].map(derivedItem(_:))
    }

    /// Returns the same item with `isWatched` and `progress` overridden by
    /// the cached leaves. For playable items (movies, episodes) this returns
    /// the item unchanged.
    func derivedItem(_ item: MediaItem) -> MediaItem {
        guard !item.kind.isPlayable else { return item }

        let itemLeaves = leaves(under: item.id)
        guard !itemLeaves.isEmpty else { return item }

        let stats = MediaItem.derivedWatchStats(fromLeaves: itemLeaves)
        return item.applyingWatchStats(
            isWatched: stats.isWatched,
            progress: stats.progress,
            resumeOffsetMilliseconds: nil
        )
    }

    /// Best-effort derived item for a synthetic library "item" (e.g. the
    /// header watch-status button on a library page) where the caller passes
    /// the library reference and we count leaves across the whole library.
    func derivedLibraryItem(_ item: MediaItem, libraryID: String) -> MediaItem {
        let leaves = leavesInLibrary(libraryID)
        guard !leaves.isEmpty else { return item }

        let stats = MediaItem.derivedWatchStats(fromLeaves: leaves)
        return item.applyingWatchStats(
            isWatched: stats.isWatched,
            progress: stats.progress,
            resumeOffsetMilliseconds: nil
        )
    }

    /// All leaves (movies/episodes/other) descending from `itemID`. Used for
    /// derivation and for fanning out watch-status writes.
    func leaves(under itemID: String) -> [MediaItem] {
        guard let item = snapshot.itemsByID[itemID] else { return [] }

        if item.kind.isPlayable {
            return [item]
        }

        let childIDs = snapshot.childItemIDs[itemID] ?? []
        return childIDs.flatMap { leaves(under: $0) }
    }

    func leavesInLibrary(_ libraryID: String) -> [MediaItem] {
        let topIDs = snapshot.libraryItemIDs[libraryID] ?? []
        return topIDs.flatMap { leaves(under: $0) }
    }

    // MARK: - Ingest (writes from connector responses)

    func ingest(items: [MediaItem], asTopLevelOf libraryID: String) {
        var next = snapshot
        next.libraryItemIDs[libraryID] = items.map(\.id)
        for item in items {
            next.itemsByID[item.id] = item
        }
        next.pruneUnreachableItems()
        snapshot = next
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
    }

    func ingest(children: [MediaItem], of parentID: String) {
        var next = snapshot
        next.childItemIDs[parentID] = children.map(\.id)
        for child in children {
            next.itemsByID[child.id] = child
        }
        next.pruneUnreachableItems()
        snapshot = next
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
    }

    func ingest(item: MediaItem) {
        var next = snapshot
        next.itemsByID[item.id] = item
        snapshot = next
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
    }

    // MARK: - Mutations

    /// Apply a watch-status change locally and return the leaves whose state
    /// changed. Callers are responsible for writing each leaf back to the
    /// server and calling `revertWatchStatus` if the network write fails.
    func applyOptimisticWatchStatus(
        for itemID: String,
        isWatched: Bool
    ) -> [MediaItem] {
        let targets = leaves(under: itemID).filter {
            if isWatched {
                return !$0.isWatched
            }

            return $0.isWatched
                || ($0.progress ?? 0) > 0
                || ($0.resumeOffsetMilliseconds ?? 0) > 0
        }

        guard !targets.isEmpty else { return [] }

        var next = snapshot
        for target in targets {
            next.itemsByID[target.id] = target.settingWatchStatus(isWatched)
        }

        snapshot = next
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
        return targets
    }

    func revertWatchStatus(to previousValues: [MediaItem]) {
        var next = snapshot
        for previous in previousValues {
            next.itemsByID[previous.id] = previous
        }

        snapshot = next
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self, snapshot, storage] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            storage.save(snapshot)
            guard !Task.isCancelled else { return }
            self?.storageSizeBytes = storage.sizeBytes()
        }
    }

    private static func serverKey(providerID: MediaProviderID, serverID: String) -> String {
        "\(providerID.rawValue):\(serverID)"
    }

    private static func formattedStorageSize(bytes: Int64) -> String {
        let kib = 1024.0
        let mib = kib * 1024.0
        let gib = mib * 1024.0
        let size = Double(bytes)

        if size < kib {
            return "\(bytes) B"
        }

        if size < mib {
            return "\(rounded(size / kib)) KiB"
        }

        if size < gib {
            return "\(rounded(size / mib)) MiB"
        }

        return "\(rounded(size / gib)) GiB"
    }

    private static func rounded(_ value: Double) -> String {
        if value < 10 {
            return String(format: "%.1f", value)
        }

        return String(format: "%.0f", value)
    }
}

struct CachedLibrary: Codable, Equatable {
    let reference: LibraryReference
    var isHidden: Bool
}

struct LibraryCacheSnapshot: Codable, Equatable {
    var serverKey: String?
    var libraries: [String: CachedLibrary]
    var libraryOrder: [String]
    var itemsByID: [String: MediaItem]
    var libraryItemIDs: [String: [String]]
    var childItemIDs: [String: [String]]

    init(
        serverKey: String? = nil,
        libraries: [String: CachedLibrary] = [:],
        libraryOrder: [String] = [],
        itemsByID: [String: MediaItem] = [:],
        libraryItemIDs: [String: [String]] = [:],
        childItemIDs: [String: [String]] = [:]
    ) {
        self.serverKey = serverKey
        self.libraries = libraries
        self.libraryOrder = libraryOrder
        self.itemsByID = itemsByID
        self.libraryItemIDs = libraryItemIDs
        self.childItemIDs = childItemIDs
    }

    var isEmpty: Bool {
        serverKey == nil
            && libraries.isEmpty
            && libraryOrder.isEmpty
            && itemsByID.isEmpty
            && libraryItemIDs.isEmpty
            && childItemIDs.isEmpty
    }

    mutating func pruneUnreachableItems() {
        var reachable: Set<String> = []

        func visit(_ itemID: String) {
            guard reachable.insert(itemID).inserted else { return }
            for childID in childItemIDs[itemID] ?? [] {
                visit(childID)
            }
        }

        for itemIDs in libraryItemIDs.values {
            for itemID in itemIDs {
                visit(itemID)
            }
        }

        itemsByID = itemsByID.filter { reachable.contains($0.key) }
        libraryItemIDs = libraryItemIDs.mapValues { $0.filter(reachable.contains) }
        childItemIDs = childItemIDs.reduce(into: [:]) { result, entry in
            guard reachable.contains(entry.key) else { return }
            result[entry.key] = entry.value.filter(reachable.contains)
        }
    }
}

struct LibraryCacheStorage {
    let load: () -> LibraryCacheSnapshot?
    let save: (LibraryCacheSnapshot) -> Void
    let clear: () -> Void
    let sizeBytes: () -> Int64

    static func defaultLocation() -> LibraryCacheStorage {
        let url = LibraryCacheStorage.fileURL()
        return LibraryCacheStorage(
            load: {
                guard let url, let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(LibraryCacheSnapshot.self, from: data)
            },
            save: { snapshot in
                guard let url else { return }

                do {
                    try FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    let data = try JSONEncoder().encode(snapshot)
                    try data.write(to: url, options: .atomic)
                } catch {}
            },
            clear: {
                guard let url else { return }
                try? FileManager.default.removeItem(at: url)
            },
            sizeBytes: {
                guard
                    let url,
                    let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                    let size = values.fileSize
                else {
                    return 0
                }

                return Int64(size)
            }
        )
    }

    static func ephemeral() -> LibraryCacheStorage {
        var storage: LibraryCacheSnapshot?
        var sizeBytes: Int64 = 0
        return LibraryCacheStorage(
            load: { storage },
            save: { snapshot in
                storage = snapshot
                sizeBytes = Int64(Self.encodedSize(of: snapshot))
            },
            clear: {
                storage = nil
                sizeBytes = 0
            },
            sizeBytes: { sizeBytes }
        )
    }

    private static func encodedSize(of snapshot: LibraryCacheSnapshot) -> Int {
        (try? JSONEncoder().encode(snapshot).count) ?? 0
    }

    private static func fileURL() -> URL? {
        let bundleID = Bundle.main.bundleIdentifier ?? "FreyaPlayer"
        return try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("library-cache.json", isDirectory: false)
    }
}

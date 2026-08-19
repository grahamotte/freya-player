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
    private(set) var snapshot: LibraryCacheSnapshot
    @Published private(set) var storageSizeBytes: Int64

    private let storage: LibraryCacheStorage
    private var pendingSave: Task<Void, Never>?
    private var pendingSnapshot: LibraryCacheSnapshot?
    private var batchDepth = 0
    private let snapshotDidChangeSubject = PassthroughSubject<LibraryCacheSnapshot, Never>()

    var snapshotDidChange: AnyPublisher<LibraryCacheSnapshot, Never> {
        snapshotDidChangeSubject.eraseToAnyPublisher()
    }

    init(storage: LibraryCacheStorage) {
        self.storage = storage
        let loadedSnapshot = storage.load()
        if let loadedSnapshot,
           loadedSnapshot.cacheVersion == LibraryCacheSnapshot.currentVersion {
            self.snapshot = loadedSnapshot
        } else {
            self.snapshot = LibraryCacheSnapshot()
            if loadedSnapshot != nil {
                storage.clear()
            }
        }
        self.storageSizeBytes = storage.sizeBytes()
    }

    var formattedStorageSize: String {
        Self.formattedStorageSize(bytes: snapshot.isEmpty ? 0 : storageSizeBytes)
    }

    func cachedServer() -> ConnectedServer? {
        let libraries = snapshot.libraryOrder.compactMap { libraryID -> LibraryShelf? in
            guard let library = snapshot.libraries[libraryID] else { return nil }
            return LibraryShelf(
                id: libraryID,
                title: library.reference.title,
                reference: library.reference,
                items: [],
                isHidden: library.isHidden
            )
        }
        guard let reference = libraries.first?.reference else { return nil }

        let metadata = snapshot.serverMetadata
        return ConnectedServer(
            providerID: metadata?.providerID ?? reference.providerID,
            serverID: metadata?.serverID ?? reference.serverID,
            serverName: metadata?.serverName ?? reference.providerID.title,
            serverURL: metadata?.serverURL ?? "",
            accountName: metadata?.accountName ?? "",
            libraries: libraries
        )
    }

    // MARK: - Server lifecycle

    func install(server: ConnectedServer) {
        let key = Self.serverKey(providerID: server.providerID, serverID: server.serverID)
        let current = mutationSnapshot
        let isCurrentServer = current.serverKey == key
        var next = isCurrentServer ? current : LibraryCacheSnapshot(serverKey: key)

        next.serverKey = key
        next.serverMetadata = CachedServerMetadata(server: server)

        var nextLibraries: [String: CachedLibrary] = [:]
        var libraryOrder: [String] = []

        for shelf in server.libraries {
            nextLibraries[shelf.id] = CachedLibrary(reference: shelf.reference, isHidden: shelf.isHidden)
            libraryOrder.append(shelf.id)

            if !isCurrentServer || next.libraryItemIDs[shelf.id] == nil {
                next.libraryItemIDs[shelf.id] = shelf.items.map(\.id)
                for item in shelf.items {
                    next.itemsByID[item.id] = item.usingCachedSeriesAddedAt(
                        from: current.itemsByID[item.id]
                    )
                }
            }
        }

        next.libraries = nextLibraries
        next.libraryOrder = libraryOrder
        next.libraryItemIDs = next.libraryItemIDs.filter { nextLibraries[$0.key] != nil }
        commit(next)
    }

    func clear() {
        pendingSave?.cancel()
        pendingSnapshot = nil
        batchDepth = 0
        let empty = LibraryCacheSnapshot()
        if snapshot != empty {
            snapshot = empty
            objectWillChange.send()
            snapshotDidChangeSubject.send(snapshot)
        }
        storage.clear()
        let nextStorageSizeBytes = storage.sizeBytes()
        if storageSizeBytes != nextStorageSizeBytes {
            storageSizeBytes = nextStorageSizeBytes
        }
    }

    // MARK: - Reads

    func libraries() -> [CachedLibrary] {
        snapshot.libraryOrder.compactMap { snapshot.libraries[$0] }
    }

    func beginBatchUpdates() {
        if batchDepth == 0 {
            pendingSnapshot = snapshot
        }
        batchDepth += 1
    }

    func endBatchUpdates() {
        guard batchDepth > 0 else { return }
        batchDepth -= 1
        guard batchDepth == 0, var next = pendingSnapshot else { return }
        pendingSnapshot = nil
        next.pruneUnreachableItems()
        guard snapshot != next else { return }
        snapshot = next
        publishSnapshot()
    }

    func libraryItems(for libraryID: String) -> [MediaItem] {
        libraryItems(for: libraryID, in: snapshot)
    }

    private func libraryItems(for libraryID: String, in source: LibraryCacheSnapshot) -> [MediaItem] {
        let ids = source.libraryItemIDs[libraryID] ?? []
        return ids.compactMap { source.itemsByID[$0] }.map { derivedItem($0, in: source) }
    }

    func children(of itemID: String) -> [MediaItem] {
        let ids = snapshot.childItemIDs[itemID] ?? []
        return ids.compactMap { snapshot.itemsByID[$0] }.map { derivedItem($0, in: snapshot) }
    }

    func item(_ itemID: String) -> MediaItem? {
        snapshot.itemsByID[itemID].map { derivedItem($0, in: snapshot) }
    }

    /// Returns the same item with `isWatched` and `progress` overridden by
    /// the cached leaves. For playable items (movies, episodes) this returns
    /// the item unchanged.
    func derivedItem(_ item: MediaItem) -> MediaItem {
        derivedItem(item, in: snapshot)
    }

    private func derivedItem(_ item: MediaItem, in source: LibraryCacheSnapshot) -> MediaItem {
        guard !item.kind.isPlayable else { return item }

        let itemLeaves = leaves(under: item.id, in: source)
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
        leaves(under: itemID, in: snapshot)
    }

    private func leaves(under itemID: String, in source: LibraryCacheSnapshot) -> [MediaItem] {
        guard let item = source.itemsByID[itemID] else { return [] }

        if item.kind.isPlayable {
            return [item]
        }

        let childIDs = source.childItemIDs[itemID] ?? []
        return childIDs.flatMap { leaves(under: $0, in: source) }
    }

    func leavesInLibrary(_ libraryID: String) -> [MediaItem] {
        let topIDs = snapshot.libraryItemIDs[libraryID] ?? []
        return topIDs.flatMap { leaves(under: $0) }
    }

    // MARK: - Ingest (writes from connector responses)

    func ingest(items: [MediaItem], asTopLevelOf libraryID: String) {
        let current = mutationSnapshot
        let resolvedItems = items.map {
            $0.usingCachedSeriesAddedAt(from: current.itemsByID[$0.id])
        }
        let itemIDs = resolvedItems.map(\.id)
        if current.libraryItemIDs[libraryID] == itemIDs,
           resolvedItems.allSatisfy({ current.itemsByID[$0.id] == $0 }) {
            return
        }

        var next = current
        next.libraryItemIDs[libraryID] = itemIDs
        for item in resolvedItems {
            next.itemsByID[item.id] = item
        }
        if batchDepth == 0 {
            next.pruneUnreachableItems()
        }
        commit(next)
    }

    func ingest(children: [MediaItem], of parentID: String) {
        let current = mutationSnapshot
        let childIDs = children.map(\.id)
        if current.childItemIDs[parentID] == childIDs,
           children.allSatisfy({ current.itemsByID[$0.id] == $0 }) {
            return
        }

        var next = current
        next.childItemIDs[parentID] = childIDs
        for child in children {
            next.itemsByID[child.id] = child
        }
        if batchDepth == 0 {
            next.pruneUnreachableItems()
        }
        commit(next)
    }

    func ingest(item: MediaItem) {
        let current = mutationSnapshot
        let item = item.usingCachedSeriesAddedAt(from: current.itemsByID[item.id])
        guard current.itemsByID[item.id] != item else { return }

        var next = current
        next.itemsByID[item.id] = item
        commit(next)
    }

    func cacheLatestEpisodeAddedAt(for seriesIDs: [String]) {
        let current = mutationSnapshot
        var next = current

        for seriesID in seriesIDs {
            guard let series = next.itemsByID[seriesID] else { continue }
            next.itemsByID[seriesID] = series.applyingLatestEpisodeAddedAt(
                from: leaves(under: seriesID, in: current)
            )
        }

        commit(next)
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

        commitUserMutation { next in
            for target in targets {
                next.itemsByID[target.id] = next.itemsByID[target.id]?.settingWatchStatus(isWatched)
            }
        }
        return targets
    }

    func revertWatchStatus(to previousValues: [MediaItem]) {
        commitUserMutation { next in
            for previous in previousValues {
                next.itemsByID[previous.id] = next.itemsByID[previous.id]?.applyingWatchStats(
                    isWatched: previous.isWatched,
                    progress: previous.progress,
                    resumeOffsetMilliseconds: previous.resumeOffsetMilliseconds
                )
            }
        }
    }

    func updatePlaybackProgress(for itemID: String, time: Int, duration: Int?) {
        guard let item = snapshot.itemsByID[itemID] else { return }
        let updated = item.applyingPlaybackProgress(time: time, duration: duration)
        guard updated != item else { return }

        commitUserMutation { next in
            next.itemsByID[itemID] = next.itemsByID[itemID]?.applyingPlaybackProgress(
                time: time,
                duration: duration
            )
        }
    }

    // MARK: - Persistence

    private var mutationSnapshot: LibraryCacheSnapshot {
        pendingSnapshot ?? snapshot
    }

    private func commit(_ next: LibraryCacheSnapshot) {
        guard mutationSnapshot != next else { return }

        if batchDepth > 0 {
            pendingSnapshot = next
            return
        }

        snapshot = next
        publishSnapshot()
    }

    private func commitUserMutation(_ mutation: (inout LibraryCacheSnapshot) -> Void) {
        var next = snapshot
        mutation(&next)
        guard snapshot != next else { return }

        snapshot = next
        if var pendingSnapshot {
            mutation(&pendingSnapshot)
            self.pendingSnapshot = pendingSnapshot
        }
        publishSnapshot()
    }

    private func publishSnapshot() {
        objectWillChange.send()
        snapshotDidChangeSubject.send(snapshot)
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self, snapshot, storage] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            storage.save(snapshot)
            guard !Task.isCancelled else { return }
            let nextStorageSizeBytes = storage.sizeBytes()
            guard self?.storageSizeBytes != nextStorageSizeBytes else { return }
            self?.storageSizeBytes = nextStorageSizeBytes
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

struct CachedServerMetadata: Codable, Equatable {
    let providerID: MediaProviderID
    let serverID: String
    let serverName: String
    let serverURL: String
    let accountName: String

    init(server: ConnectedServer) {
        providerID = server.providerID
        serverID = server.serverID
        serverName = server.serverName
        serverURL = server.serverURL
        accountName = server.accountName
    }
}

struct LibraryCacheSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var cacheVersion: Int?
    var serverKey: String?
    var serverMetadata: CachedServerMetadata?
    var libraries: [String: CachedLibrary]
    var libraryOrder: [String]
    var itemsByID: [String: MediaItem]
    var libraryItemIDs: [String: [String]]
    var childItemIDs: [String: [String]]

    init(
        cacheVersion: Int? = LibraryCacheSnapshot.currentVersion,
        serverKey: String? = nil,
        serverMetadata: CachedServerMetadata? = nil,
        libraries: [String: CachedLibrary] = [:],
        libraryOrder: [String] = [],
        itemsByID: [String: MediaItem] = [:],
        libraryItemIDs: [String: [String]] = [:],
        childItemIDs: [String: [String]] = [:]
    ) {
        self.cacheVersion = cacheVersion
        self.serverKey = serverKey
        self.serverMetadata = serverMetadata
        self.libraries = libraries
        self.libraryOrder = libraryOrder
        self.itemsByID = itemsByID
        self.libraryItemIDs = libraryItemIDs
        self.childItemIDs = childItemIDs
    }

    var isEmpty: Bool {
        serverKey == nil
            && serverMetadata == nil
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

import Combine
import Foundation

/// A typed key identifying an in-flight refresh. Keeps callers from building
/// stringly-typed keys and lets views ask `isRefreshing(.children(itemID))`
/// directly.
enum RefreshKey: Hashable, Sendable {
    case allLibraries
    case connection
    case library(String)
    case children(String)
    case item(String)
}

struct RefreshProgress: Equatable {
    let completed: Int
    let total: Int
}

/// Tracks the set of background refreshes currently in flight and dedups
/// concurrent calls for the same `RefreshKey`.
///
/// `AppModel` owns one tracker. All public refresh / mutation entry points on
/// `AppModel` route through `tracker.run(key) { ... }`:
///
/// - The first call for a key spawns a `Task`, runs `work`, then clears the key.
/// - Subsequent calls for the same key (until completion) reuse the in-flight
///   `Task` instead of doing the work twice. Internal callers can `await` the
///   returned task; UI callers ignore it.
///
/// Views observe `inFlight` (or the typed `isRefreshing(_:)` helper) to drive
/// empty-state spinners. The tracker lives on `MainActor` so all reads/writes
/// happen on the same isolation as the cache and the SwiftUI views.
@MainActor
final class RefreshTracker: ObservableObject {
    @Published private(set) var inFlight: Set<RefreshKey> = []
    @Published private(set) var progress: RefreshProgress?
    private var tasks: [RefreshKey: Task<Void, Never>] = [:]
    private var tokens: [RefreshKey: UUID] = [:]
    private var refreshID: UUID?

    func beginRefresh() -> UUID? {
        guard refreshID == nil else { return nil }

        let id = UUID()
        refreshID = id
        progress = RefreshProgress(completed: 0, total: 0)
        return id
    }

    func registerRequest(for id: UUID?) -> Bool {
        guard let id, refreshID == id, let progress else { return false }
        self.progress = RefreshProgress(completed: progress.completed, total: progress.total + 1)
        return true
    }

    func completeRequest(for id: UUID?) {
        guard let id, refreshID == id, let progress else { return }
        self.progress = RefreshProgress(completed: progress.completed + 1, total: progress.total)
    }

    func finishRefresh(_ id: UUID) {
        guard refreshID == id else { return }
        refreshID = nil
        progress = nil
    }

    @discardableResult
    func run(_ key: RefreshKey, _ work: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        if let existing = tasks[key] {
            return existing
        }

        let token = UUID()
        tokens[key] = token
        inFlight.insert(key)
        let task = Task { [weak self] in
            await work()
            guard self?.tokens[key] == token else { return }
            self?.tasks[key] = nil
            self?.tokens[key] = nil
            self?.inFlight.remove(key)
        }
        tasks[key] = task
        return task
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        tokens.removeAll()
        inFlight.removeAll()
        refreshID = nil
        progress = nil
    }

    func isRefreshing(_ key: RefreshKey) -> Bool {
        inFlight.contains(key)
    }
}

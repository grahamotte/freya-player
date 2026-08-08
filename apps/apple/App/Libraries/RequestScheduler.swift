import Foundation

/// Caps the number of concurrent network requests across the whole app.
///
/// Every HTTP call from `PlexClient` and `JellyfinClient` flows through
/// `RequestScheduler.shared.run { ... }`. New requests over the cap suspend
/// until a slot frees. Playback bypasses queued refresh work, and cancelled
/// callers are removed before they consume a slot.
actor RequestScheduler {
    static let shared = RequestScheduler(limit: 4)

    enum Priority: Int {
        case normal
        case playback
    }

    private struct Waiter {
        let id: UUID
        let priority: Priority
        let continuation: CheckedContinuation<Void, Error>
    }

    private let limit: Int
    private var inFlight = 0
    private var waiters: [Waiter] = []

    init(limit: Int) {
        self.limit = limit
    }

    func run<T: Sendable>(
        priority: Priority = .normal,
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        try await acquire(priority: priority)
        defer { release() }
        try Task.checkCancellation()
        return try await work()
    }

    private func acquire(priority: Priority) async throws {
        try Task.checkCancellation()
        if inFlight < limit {
            inFlight += 1
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, priority: priority, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func nextWaiterIndex() -> Int? {
        guard var index = waiters.indices.first else { return nil }
        for candidate in waiters.indices.dropFirst() where waiters[candidate].priority.rawValue > waiters[index].priority.rawValue {
            index = candidate
        }
        return index
    }

    private func release() {
        if let index = nextWaiterIndex() {
            waiters.remove(at: index).continuation.resume()
        } else {
            inFlight = max(0, inFlight - 1)
        }
    }
}

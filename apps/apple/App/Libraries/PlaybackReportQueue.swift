import Foundation

@MainActor
final class PlaybackReportQueue<Key: Hashable> {
    private struct Entry {
        let token: UUID
        let task: Task<Void, Never>
    }

    private var entries: [Key: Entry] = [:]
    private var terminalKeys: Set<Key> = []
    private var finalizedKeys: Set<Key> = []

    func enqueue(
        for key: Key,
        isTerminal: Bool = false,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard !terminalKeys.contains(key) else { return }
        if isTerminal {
            terminalKeys.insert(key)
        }
        append(for: key, operation: operation)
    }

    func enqueueFinalization(
        for key: Key,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard finalizedKeys.insert(key).inserted else { return }
        terminalKeys.insert(key)
        append(for: key, operation: operation)
    }

    func drain() async {
        let tasks = entries.values.map(\.task)
        for task in tasks {
            await task.value
        }
    }

    private func append(
        for key: Key,
        operation: @escaping @MainActor () async -> Void
    ) {
        let previousTask = entries[key]?.task
        let token = UUID()
        let task = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self, !Task.isCancelled else { return }
            await operation()
            guard entries[key]?.token == token else { return }
            entries[key] = nil
        }
        entries[key] = Entry(token: token, task: task)
    }
}

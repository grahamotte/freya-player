import Foundation

/// Cadence loop that fires `action` immediately and then every `interval`.
///
/// `action` is intentionally sync + `@MainActor`: the body should kick off
/// background refreshes via the fire-and-forget `AppModel` API rather than
/// awaiting any network work directly.
@MainActor
enum PollingLoop {
    static func run(
        every interval: Duration = .seconds(600),
        _ action: @escaping @MainActor () -> Void
    ) async {
        action()

        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

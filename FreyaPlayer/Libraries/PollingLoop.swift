import Foundation

enum PollingLoop {
    static func run(
        every interval: Duration = .seconds(10),
        _ action: @escaping @Sendable () async -> Void
    ) async {
        await action()

        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
}

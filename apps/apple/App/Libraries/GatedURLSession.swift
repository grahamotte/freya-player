import Foundation

extension URLSession {
    /// Drop-in replacement for `data(for:)` that goes through `RequestScheduler.shared`.
    /// Use this from connectors so concurrent HTTP work is capped centrally.
    func gatedData(
        for request: URLRequest,
        priority: RequestScheduler.Priority = .normal
    ) async throws -> (Data, URLResponse) {
        var timedRequest = request
        timedRequest.timeoutInterval = min(timedRequest.timeoutInterval, 15)
        let request = timedRequest
        return try await RequestScheduler.shared.run(priority: priority) {
            try await self.data(for: request)
        }
    }
}

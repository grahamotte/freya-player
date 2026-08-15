import XCTest
@testable import FreyaPlayerCore

@MainActor
final class PlaybackReportQueueTests: XCTestCase {
    func testSerializesOperationsForTheSameKey() async {
        let queue = PlaybackReportQueue<String>()
        let gate = PlaybackReportQueueGate()
        var events: [String] = []

        queue.enqueue(for: "session") {
            await gate.wait()
            events.append("first")
        }
        queue.enqueue(for: "session") {
            events.append("second")
        }

        await gate.waitUntilBlocked()
        XCTAssertTrue(events.isEmpty)
        await gate.open()
        await queue.drain()

        XCTAssertEqual(events, ["first", "second"])
    }

    func testTerminalOperationDropsLaterEventsButAllowsFinalization() async {
        let queue = PlaybackReportQueue<String>()
        var events: [String] = []

        queue.enqueue(for: "session", isTerminal: true) {
            events.append("stopped")
        }
        queue.enqueue(for: "session") {
            events.append("late progress")
        }
        queue.enqueueFinalization(for: "session") {
            events.append("completed")
        }
        queue.enqueueFinalization(for: "session") {
            events.append("duplicate completion")
        }

        await queue.drain()

        XCTAssertEqual(events, ["stopped", "completed"])
    }
}

private actor PlaybackReportQueueGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var blockedContinuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            blockedContinuation?.resume()
            blockedContinuation = nil
        }
    }

    func waitUntilBlocked() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { continuation in
            blockedContinuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

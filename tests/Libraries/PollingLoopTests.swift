import Foundation
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PollingLoopTests: XCTestCase {
    func testRunsImmediatelyAndStopsOnCancellation() async {
        let counter = LockedCounter()
        let task = Task {
            await PollingLoop.run(every: .milliseconds(20)) {
                counter.increment()
            }
        }

        await waitUntil {
            counter.value >= 2
        }

        task.cancel()
        let valueBeforePause = counter.value
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertGreaterThanOrEqual(valueBeforePause, 2)
        XCTAssertEqual(counter.value, valueBeforePause)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}

import Network
import XCTest
@testable import FreyaPlayerCore

@MainActor
final class NetworkMonitorTests: XCTestCase {
    func testOnlyUnsatisfiedPathsAreOffline() {
        XCTAssertTrue(NetworkMonitor.isOffline(pathStatus: .unsatisfied))
        XCTAssertFalse(NetworkMonitor.isOffline(pathStatus: .satisfied))
        XCTAssertFalse(NetworkMonitor.isOffline(pathStatus: .requiresConnection))
    }
}

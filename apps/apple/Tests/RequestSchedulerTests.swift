import XCTest
@testable import FreyaPlayerCore

final class RequestSchedulerTests: XCTestCase {
    func testRunReturnsValuesAndErrors() async throws {
        let scheduler = RequestScheduler(limit: 1)
        let value = try await scheduler.run { 42 }
        XCTAssertEqual(value, 42)

        do {
            _ = try await scheduler.run { throw TestError.expected } as Int
            XCTFail("Expected an error")
        } catch TestError.expected {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum TestError: Error {
    case expected
}

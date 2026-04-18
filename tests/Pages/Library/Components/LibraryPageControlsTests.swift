import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class LibraryPageControlsTests: XCTestCase {
    func testFiltersSortsAndEmptyStateText() {
        let a = makeMediaItem(id: "a", title: "B", addedAt: 200, durationMilliseconds: nil, isWatched: true)
        let b = makeMediaItem(id: "b", title: "A", addedAt: 100, durationMilliseconds: 10)
        let c = makeMediaItem(id: "c", title: "C", addedAt: nil, durationMilliseconds: 20)
        let items = [a, b, c]

        XCTAssertEqual(LibraryPageFilter.unwatched.emptyStateText(for: "movie"), "No unwatched movies.")
        XCTAssertEqual(LibraryPageSort.title.items(from: items, order: .ascending).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(LibraryPageSort.addedAt.items(from: items, order: .descending).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(LibraryPageSort.duration.items(from: items, order: .ascending).map(\.id), ["a", "b", "c"])
        XCTAssertTrue(LibraryPageFilter.all.matches(a))
        XCTAssertFalse(LibraryPageFilter.unwatched.matches(a))
        XCTAssertTrue(LibraryPageSortOrder.descending.compare(false))
    }
}

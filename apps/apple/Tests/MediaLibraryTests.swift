import XCTest
@testable import FreyaPlayerCore

final class MediaLibraryTests: XCTestCase {
    func testRecentItemsAreUnwatchedSortedAndLimited() {
        let items = (0..<25).map {
            makeMediaItem(
                id: String($0),
                title: "Movie \($0)",
                addedAt: $0,
                isWatched: $0 == 24
            )
        }
        let shelf = makeLibraryShelf(items: items)

        XCTAssertEqual(shelf.recentUnwatchedItems.count, 20)
        XCTAssertEqual(shelf.recentUnwatchedItems.first?.id, "23")
        XCTAssertFalse(shelf.settingHidden(true).items.isEmpty)
    }

    func testLibraryWatchStatusUsesVisibleItems() {
        let reference = makeLibraryReference()
        let item = reference.watchStatusItem(from: [
            makeMediaItem(id: "watched", isWatched: true),
            makeMediaItem(id: "started", progress: 0.5),
        ])

        XCTAssertEqual(item?.id, "library:library")
        XCTAssertEqual(item?.progress, 0.75)
        XCTAssertFalse(item?.isWatched ?? true)
    }
}

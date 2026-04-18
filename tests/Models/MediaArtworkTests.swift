import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class MediaArtworkTests: XCTestCase {
    func testStyleSizingAndLookup() {
        let artwork = makeArtwork()

        XCTAssertEqual(artwork.url(for: .poster), artwork.posterURL)
        XCTAssertEqual(artwork.url(for: .landscape), artwork.landscapeURL)
        XCTAssertEqual(MediaArtworkStyle.poster.aspectRatio, 2 / 3)
        XCTAssertEqual(MediaArtworkStyle.poster.imageRequestWidth, 960)
        XCTAssertEqual(MediaArtworkStyle.poster.imageRequestHeight, 1440)

        let fitted = MediaArtworkStyle.landscape.fittedSize(in: CGSize(width: 300, height: 120))
        XCTAssertEqual(fitted.width, 213.33333333333331, accuracy: 0.0001)
        XCTAssertEqual(fitted.height, 120, accuracy: 0.0001)
    }
}

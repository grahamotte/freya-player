import CoreGraphics
import XCTest
@testable import FreyaPlayerCore

final class MediaArtworkTests: XCTestCase {
    func testStyleSizingAndLookup() {
        let poster = URL(string: "https://example.com/poster")
        let landscape = URL(string: "https://example.com/landscape")
        let artwork = MediaArtworkSet(posterURL: poster, landscapeURL: landscape, backdropURL: nil)

        XCTAssertEqual(artwork.url(for: .poster), poster)
        XCTAssertEqual(artwork.url(for: .landscape), poster)
        XCTAssertEqual(MediaArtworkStyle.poster.imageRequestWidth, 960)
        XCTAssertEqual(MediaArtworkStyle.poster.imageRequestHeight, 1440)

        let fitted = MediaArtworkStyle.landscape.fittedSize(in: CGSize(width: 300, height: 120))
        XCTAssertEqual(fitted.width, 213.33333333333331, accuracy: 0.0001)
        XCTAssertEqual(fitted.height, 120, accuracy: 0.0001)
    }
}

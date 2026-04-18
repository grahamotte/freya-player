import UIKit
import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class ArtworkImageCacheTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.reset()
    }

    func testLoadImageCachesSuccessfulImage() async {
        let url = URL(string: "https://example.com/image.png")!
        let cache = ArtworkImageCache(session: makeTestSession())

        TestURLProtocol.handler = { request in
            XCTAssertEqual(request.url, url)
            return StubbedHTTPResponse(headers: ["Content-Type": "image/png"], body: self.imageData())
        }

        let first = await cache.loadImage(from: url)
        let second = await cache.loadImage(from: url)

        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
        XCTAssertEqual(TestURLProtocol.requests.count, 1)
    }

    func testLoadImageReturnsNilForFailures() async {
        let url = URL(string: "https://example.com/image.png")!
        let cache = ArtworkImageCache(session: makeTestSession())

        TestURLProtocol.handler = { _ in
            StubbedHTTPResponse(statusCode: 500, body: Data())
        }

        let image = await cache.loadImage(from: url)
        XCTAssertNil(image)
        XCTAssertNil(cache.image(for: url))
    }

    private func imageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

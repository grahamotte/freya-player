import Foundation
import XCTest
@testable import FreyaPlayerCore

final class GatedURLSessionTests: XCTestCase {
    func testGatedDataIgnoresLocalCache() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CachePolicyURLProtocol.self]
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: URL(string: "https://example.com/library")!)
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, _) = try await session.gatedData(for: request)

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            String(URLRequest.CachePolicy.reloadIgnoringLocalCacheData.rawValue)
        )
    }
}

private final class CachePolicyURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let data = Data(String(request.cachePolicy.rawValue).utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

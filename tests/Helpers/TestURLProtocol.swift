import Foundation

struct StubbedHTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int = 200, headers: [String: String] = ["Content-Type": "application/json"], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

final class TestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> StubbedHTTPResponse)?

    private static let lock = NSLock()
    private static var requestsStorage: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { requestsStorage }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            requestsStorage = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.lock.withLock { () -> ((URLRequest) throws -> StubbedHTTPResponse)? in
            Self.requestsStorage.append(request)
            return Self.handler
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let stub = try handler(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://invalid.local")!,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeTestSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TestURLProtocol.self]
    return URLSession(configuration: configuration)
}

func jsonBody(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

func jsonResponse(_ object: Any, statusCode: Int = 200) -> StubbedHTTPResponse {
    StubbedHTTPResponse(statusCode: statusCode, body: jsonBody(object))
}

func queryItems(for request: URLRequest) -> [String: String] {
    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
        .queryItems?
        .reduce(into: [:]) { partial, item in
            partial[item.name] = item.value
        } ?? [:]
}

func jsonObjectBody(for request: URLRequest) -> [String: Any] {
    guard let data = request.httpBody ?? streamData(for: request.httpBodyStream) else { return [:] }
    return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

private func streamData(for stream: InputStream?) -> Data? {
    guard let stream else { return nil }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        guard count > 0 else { break }
        data.append(buffer, count: count)
    }

    return data
}

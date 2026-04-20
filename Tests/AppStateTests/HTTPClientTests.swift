import XCTest
@testable import AppState

final class HTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func test_givenSuccessResponse_whenSending_thenReturnsAccepted() async throws {
        StubURLProtocol.responder = { _ in
            (HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 202, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = makeClient()
        let outcome = try await client.send(Event(name: "x"))

        XCTAssertEqual(outcome, .accepted)
    }

    func test_givenClientError_whenSending_thenReturnsRejected() async throws {
        StubURLProtocol.responder = { _ in
            (HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 400, httpVersion: nil, headerFields: nil)!, Data("bad".utf8))
        }

        let client = makeClient()
        let outcome = try await client.send(Event(name: "x"))

        XCTAssertEqual(outcome, .rejected(status: 400, body: "bad"))
    }

    func test_givenServerError_whenSending_thenReturnsRetryable() async throws {
        StubURLProtocol.responder = { _ in
            (HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = makeClient()
        let outcome = try await client.send(Event(name: "x"))

        if case .retryable = outcome { return }
        XCTFail("expected retryable, got \(outcome)")
    }

    func test_givenRequest_whenSending_thenUsesBearerAuth() async throws {
        StubURLProtocol.responder = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.url?.path, "/v1/events")
            return (HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = makeClient()
        _ = try await client.send(Event(name: "x"))
    }

    private func makeClient() -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return HTTPClient(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.example.com")!,
            session: session,
            timeout: 5
        )
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (HTTPURLResponse, Data))?

    static func reset() {
        responder = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = StubURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

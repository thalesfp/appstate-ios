import Foundation

public final class HTTPClient: Transport {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let timeout: TimeInterval

    public init(apiKey: String, baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
    }

    public func send(_ event: Event) async throws -> TransportOutcome {
        let url = baseURL.appendingPathComponent("v1/events")

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(event)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .retryable(reason: "network: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return .accepted
        case 400..<500:
            let body = String(data: data, encoding: .utf8) ?? ""
            return .rejected(status: http.statusCode, body: body)
        default:
            return .retryable(reason: "http \(http.statusCode)")
        }
    }
}

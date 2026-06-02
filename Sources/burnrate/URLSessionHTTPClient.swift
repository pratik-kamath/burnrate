import Foundation
import BurnrateCore

struct URLSessionHTTPClient: HTTPClient {
    func get(url: URL, headers: [String: String]) async throws -> HTTPResponse {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(statusCode: code, body: data)
    }
}

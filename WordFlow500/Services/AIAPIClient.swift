import Foundation
import Combine

@MainActor
final class AIAPIClient: ObservableObject {
    let baseURL: URL
    let secret: String?

    init(
        baseURL: URL = URL(string: "https://lifeos.pifagoryy.workers.dev/api/ai")!,
        secret: String? = nil
    ) {
        self.baseURL = baseURL
        self.secret = secret
    }

    func post<Request: Encodable, Response: Decodable>(
        _ path: String,
        body: Request
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret, !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
import Foundation

struct PiStatus: Codable {
    let present: Bool
    let emotion: String?
    let emotion_conf: Double?
    let embedding: String?       // base64 or hex string from Pi; we’ll parse both
    let embedding_hash: String?  // optional quick identity
    let last_seen_ts: Int?
}

final class PiClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseIP: String, session: URLSession = .shared) {
        self.baseURL = URL(string: "http://\(baseIP):8000")!
        self.session = session
    }
    func getStatus() async throws -> PiStatus {
        let url = baseURL.appendingPathComponent("status")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(PiStatus.self, from: data)
    }
    
    func postText(_ text: String) async throws {
        let url = baseURL.appendingPathComponent("display/text")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["text": text]
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await session.data(for: req)
    }

    func postProgress(imageID: String) async throws {
        // imageID must be progress_0|progress_25|progress_50|progress_75|progress_100
        let url = baseURL.appendingPathComponent("display/progress")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["image_id": imageID]
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await session.data(for: req)
    }
}

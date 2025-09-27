import Foundation

enum GeminiClient {
    enum GErr: Error { case noKey, badResponse(String) }

    static func emotionFromImageJPEG(_ jpeg: Data) async throws -> String {
        guard let key = Secret.geminiKey else { throw GErr.noKey }

        let boundary = "----otome-boundary-\(UUID().uuidString)"
        var req = URLRequest(url: URL(string:
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(key)")!)
        req.httpMethod = "POST"
        req.addValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are a facial expression classifier. Return ONLY JSON:
        {"emotion":"happy|sad|angry|neutral"}
        """

        let json1: [String: Any] = [
          "contents":[["parts":[["text": prompt]]]],
          "generationConfig":[ "responseMimeType":"application/json" ]
        ]
        let json1Data = try JSONSerialization.data(withJSONObject: json1, options: [])

        var body = Data()
        func add(_ s: String) { body.append(s.data(using: .utf8)!) }

        add("--\(boundary)\r\n")
        add("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(json1Data); add("\r\n")

        add("--\(boundary)\r\n")
        add("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpeg); add("\r\n")

        add("--\(boundary)--\r\n")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GErr.badResponse(String(data: data, encoding: .utf8) ?? "HTTP error")
        }

        struct G: Decodable {
            struct C: Decodable { struct Ct: Decodable { struct P: Decodable { let text: String? }; let parts:[P] }; let content: Ct }
            let candidates:[C]
        }
        let g = try JSONDecoder().decode(G.self, from: data)
        let text = g.candidates.first?.content.parts.first?.text ?? "{}"
        let obj = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String:Any]
        let emo = (obj?["emotion"] as? String)?.lowercased() ?? "neutral"
        return ["happy","sad","angry","neutral"].contains(emo) ? emo : "neutral"
    }
}
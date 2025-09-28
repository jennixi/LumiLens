import Foundation

protocol DialogueProvider {
    func line(forEmotion emotion: String) async throws -> String
}

enum DialogueError: Error { case emptyResponse }

final class GeminiDialogueProvider: DialogueProvider {
    private let apiKey: String
    private let model = "gemini-1.5-flash" // choose model variant

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func line(forEmotion emotion: String) async throws -> String {
        guard !apiKey.isEmpty else {
            return Self.mockLine(for: emotion)
        }

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else {
            return Self.mockLine(for: emotion)
        }

        let prompt = """
        Give one short, friendly line to say to someone who feels \(emotion.lowercased()).
        Keep it under 80 characters, no emojis.
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                let msg = String(data: data, encoding: .utf8) ?? "<no body>"
                print("Gemini error \(http.statusCode): \(msg)")
                return Self.mockLine(for: emotion)
            }

            if
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let text = parts.first?["text"] as? String
            {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            throw DialogueError.emptyResponse
        } catch {
            print("Gemini request failed: \(error)")
            return Self.mockLine(for: emotion)
        }
    }

    private static func mockLine(for emotion: String) -> String {
        switch emotion.lowercased() {
        case "happy", "surprise":
            return ["Love that for you!", "That’s awesome—what made your day?", "Heck yes—tell me more!"].randomElement()!
        case "neutral":
            return ["How’s everything going?", "What’s on your mind?", "I’m here—what’s next?"].randomElement()!
        case "angry", "disgust", "fear", "sad", "upset":
            return ["I hear you—what feels toughest?", "That’s rough—want to unpack it?", "I’m here—one step at a time."].randomElement()!
        default:
            return ["How are you feeling right now?", "Tell me more.", "I’m listening."].randomElement()!
        }
    }
}

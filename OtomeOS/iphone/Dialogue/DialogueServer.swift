import Foundation
import Swifter

final class DialogueServer {
    func handleDialogueAudio(req: HttpRequest) -> HttpResponse {
        // WAV is in req.body; you can pass to SFSpeech later
        let _ = Data(req.body)
        // For MVP, return canned options
        let json: [String: Any] = [
            "options": [
                "Ask about the project",
                "Share your progress",
                "Suggest a study jam"
            ]
        ]
        return jsonResponse(json)
    }

    private func jsonResponse(_ obj: Any) -> HttpResponse {
        let data = try! JSONSerialization.data(withJSONObject: obj, options: [])
        return .raw(200, "OK", ["Content-Type":"application/json"]) { try? $0.write(data) }
    }
}
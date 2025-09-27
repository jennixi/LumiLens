import Foundation
import Swifter

final class FaceServer {

    func handleEnroll(req: HttpRequest) -> HttpResponse {
        let q = Dictionary(uniqueKeysWithValues: req.queryParams.map { ($0.0, $0.1) })
        guard let name = q["name"], !name.isEmpty else { return .badRequest(nil) }
        let note = q["note"] ?? ""
        let jpeg = Data(req.body)
        do {
            let emb = try awaitEmbed(jpeg)
            FaceStore.shared.enroll(name: name, note: note, embedding: emb)
            return json(["ok": true, "count": FaceStore.shared.profiles.count])
        } catch {
            return json(["error":"\(error)"], code: 500)
        }
    }

    /// Receives a JPEG from the Pi, does local identity matching + Gemini emotion (with fallback).
    func handleRecognize(req: HttpRequest) -> HttpResponse {
        let jpeg = Data(req.body)
        do {
            // 1) Local identity match (Vision embedding + FaceStore)
            var name = "Unknown", note = "", score: Float = 0
            if let m = FaceStore.shared.bestMatch(for: try awaitEmbed(jpeg)) {
                name = m.name; note = m.note; score = m.score
            }

            // 2) Emotion via Gemini (if a key exists), else neutral fallback
            let emotion: String
            if let _ = Secret.geminiKey {
                // If the call fails for any reason, default to neutral so the demo never breaks
                emotion = (try? await GeminiClient.emotionFromImageJPEG(jpeg)) ?? "neutral"
            } else {
                emotion = "neutral"
            }

            // 3) Return compact JSON for Pi/UI
            return json(["name": name, "note": note, "score": score, "emotion": emotion])

        } catch {
            return json(["error":"\(error)"], code: 500)
        }
    }

    // sync bridge around async Vision
    private func awaitEmbed(_ data: Data) throws -> [Float] {
        let sem = DispatchSemaphore(value: 0)
        var res: Result<[Float], Error>!
        Task {
            do { res = .success(try await faceEmbedding(from: data)) }
            catch { res = .failure(error) }
            sem.signal()
        }
        sem.wait()
        switch res! { case .success(let v): return v; case .failure(let e): throw e }
    }

    private func json(_ obj: Any, code: Int32 = 200) -> HttpResponse {
        let data = try! JSONSerialization.data(withJSONObject: obj, options: [])
        return .raw(code,"OK",["Content-Type":"application/json"]) { try? $0.write(data) }
    }
}
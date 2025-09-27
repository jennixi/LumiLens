import Foundation
import Swifter

final class WebServerManager: ObservableObject {
    private let server = HttpServer()
    @Published var log:[String] = []
    @Published var ip:String = "192.168.1.xxx"   // set manually or implement lookup
    @Published var port: in_port_t = 8080
    @Published var isRunning = false

    private let dialogue = DialogueServer()
    private let face = FaceServer()

    init() {
        // health check
        server["/"] = { _ in .ok(.text("OtomePhone OK")) }

        // dialogue route
        server.POST["/dialogueAudio"] = { [weak self] req in
            self?.append("dialogueAudio: \(req.body.count) bytes")
            return self?.dialogue.handleDialogueAudio(req: req) ?? .internalServerError
        }

        // face routes
        server.POST["/enroll"] = { [weak self] req in
            self?.append("enroll: \(req.body.count) bytes")
            return self?.face.handleEnroll(req: req) ?? .internalServerError
        }
        server.POST["/recognize"] = { [weak self] req in
            self?.append("recognize: \(req.body.count) bytes")
            return self?.face.handleRecognize(req: req) ?? .internalServerError
        }
    }

    func start(){
        guard !isRunning else { return }
        do { try server.start(port, forceIPv4: true); isRunning = true; append("Server started on \(ip):\(port)") }
        catch { append("Server error: \(error)") }
    }
    func stop(){ server.stop(); isRunning = false; append("Server stopped") }

    private func append(_ s:String){
        DispatchQueue.main.async {
            let ts = ISO8601DateFormatter().string(from: Date())
            self.log.insert("[\(ts)] \(s)", at: 0)
        }
    }
}
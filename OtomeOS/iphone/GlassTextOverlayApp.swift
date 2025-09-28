import SwiftUI
import AVFoundation

// MARK: - APP

@main
struct GlassTextOverlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { ExternalDisplayManager.shared.start() }
        }
    }
}

// MARK: - EMOTION + CONTROLLER

enum Emotion: String, CaseIterable, Identifiable {
    case happy, sad, anxious, angry, surprised, neutral
    var id: String { rawValue.capitalized }
}

@MainActor
final class OverlayState: ObservableObject {
    @Published var text: String = "Load a .txt or use AI mode."
    @Published var fontSize: CGFloat = 28
    @Published var highContrast = true
    @Published var blurBackground = true
    @Published var alignment: TextAlignment = .center
}

final class EmotionAIController: ObservableObject {
    @Published var emotion: Emotion = .neutral
    @Published var context: String? = nil
    @Published var useAI = false

    private let client = GeminiClient()
    private var lastFetch: Date = .distantPast
    private let minInterval: TimeInterval = 3.0
    private var task: Task<Void, Never>?

    func start(state: OverlayState) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification).map({ _ in () }) {
                // no-op, placeholder to keep task alive
                _ = ()
            }
        }
        // Kick off polling loop for AI mode
        Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if useAI, shouldFetch() {
                    await fetchLine(into: state)
                }
            }
        }
    }

    private func shouldFetch() -> Bool {
        Date().timeIntervalSince(lastFetch) > minInterval
    }

    private func markFetched() { lastFetch = Date() }

    private func fetchLine(into state: OverlayState) async {
        markFetched()
        do {
            let line = try await client.suggestLine(emotion: emotion, context: context)
            await MainActor.run {
                state.text = line
                ExternalDisplayManager.shared.push(text: line, fontSize: state.fontSize, highContrast: state.highContrast)
            }
        } catch {
            let fallback = client.suggestLineOffline(emotion: emotion, context: context)
            await MainActor.run {
                state.text = fallback
                ExternalDisplayManager.shared.push(text: fallback, fontSize: state.fontSize, highContrast: state.highContrast)
            }
        }
    }

    func emotionDidChange(into state: OverlayState) {
        guard useAI else { return }
        Task { await fetchLine(into: state) }
    }
}

// MARK: - GEMINI CLIENT

final class GeminiClient {
    private struct Cfg {
        let model = "gemini-1.5-flash"
        let base = "https://generativelanguage.googleapis.com/v1beta/models"
        var key: String { Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? "" }
    }
    private let cfg = Cfg()

    struct Resp: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable { struct Part: Decodable { let text: String? }; let parts: [Part] }
            let content: Content
        }
        let candidates: [Candidate]?
    }

    func suggestLine(emotion: Emotion, context: String?) async throws -> String {
        guard !cfg.key.isEmpty else {
            throw NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing API key"])
        }
        let url = URL(string: "\(cfg.base)/\(cfg.model):generateContent?key=\(cfg.key)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt =
        """
        You are a supportive overlay for assistive glasses.
        Output ONE short sentence (max 12 words). No emojis, no quotes.
        Tone: friendly, concrete, neurodivergent-safe.
        Detected emotion: \(emotion.rawValue).
        \(context.map { "Context: \($0)" } ?? "")
        """

        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [["text": prompt]]
            ]],
            "generationConfig": [
                "temperature": 0.6,
                "maxOutputTokens": 28,
                "topP": 0.9
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Gemini", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini error: \(s)"])
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let text = decoded.candidates?.first?.content.parts.compactMap { $0.text }.joined() ?? ""
        let clean = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? suggestLineOffline(emotion: emotion, context: context) : clean
    }

    func suggestLineOffline(emotion: Emotion, context: String?) -> String {
        switch emotion {
        case .happy: return "Love that energy—want to share it?"
        case .sad: return "I’m here. Try one slow breath."
        case .anxious: return "Grounding: name three things you see."
        case .angry: return "Pause. Unclench jaw, drop shoulders."
        case .surprised: return "Take a second to process."
        case .neutral: return "All good—ready for the next step?"
        }
    }
}

// MARK: - CONTENT VIEW (Camera + Overlay + Controls)

struct ContentView: View {
    @StateObject private var state = OverlayState()
    @StateObject private var ai = EmotionAIController()
    @State private var showPicker = false
    @State private var tempContext = ""

    var body: some View {
        ZStack {
            CameraView().ignoresSafeArea()

            VStack {
                Spacer()
                Text(state.text)
                    .font(.system(size: state.fontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(state.highContrast ? .white : .primary)
                    .multilineTextAlignment(state.alignment)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if state.blurBackground { VisualEffectBlur() }
                            else { RoundedRectangle(cornerRadius: 20).fill(state.highContrast ? .black.opacity(0.55) : .clear) }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            ai.start(state: state)
            ExternalDisplayManager.shared.setOverlaySource { state.text }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Load .txt") { showPicker = true }
                Slider(value: $state.fontSize, in: 16...64) { Text("Font") }.frame(width: 140)
                Toggle("HC", isOn: $state.highContrast).toggleStyle(.button)
                Toggle("Blur", isOn: $state.blurBackground).toggleStyle(.button)
                Menu("Align") {
                    Button("Left") { state.alignment = .leading }
                    Button("Center") { state.alignment = .center }
                    Button("Right") { state.alignment = .trailing }
                }
                Divider()
                Toggle("AI mode", isOn: $ai.useAI).toggleStyle(.button)
                Menu(ai.emotion.id) {
                    ForEach(Emotion.allCases) { e in
                        Button(e.id) {
                            ai.emotion = e
                            ai.emotionDidChange(into: state)
                        }
                    }
                }
                TextField("Context", text: $tempContext, prompt: Text("optional"))
                    .frame(maxWidth: 160)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        ai.context = tempContext.isEmpty ? nil : tempContext
                        ai.emotionDidChange(into: state)
                    }
            }
        }
        .sheet(isPresented: $showPicker) {
            DocumentPicker { text in
                if let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    state.text = t
                    ExternalDisplayManager.shared.push(text: t, fontSize: state.fontSize, highContrast: state.highContrast)
                }
            }
        }
        .onChange(of: state.fontSize) { _, _ in ExternalDisplayManager.shared.push(text: state.text, fontSize: state.fontSize, highContrast: state.highContrast) }
        .onChange(of: state.highContrast) { _, _ in ExternalDisplayManager.shared.push(text: state.text, fontSize: state.fontSize, highContrast: state.highContrast) }
        .onChange(of: state.text) { _, _ in ExternalDisplayManager.shared.push(text: state.text, fontSize: state.fontSize, highContrast: state.highContrast) }
    }
}

// MARK: - CAMERA

struct CameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = CameraPreview()
        view.start()
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class CameraPreview: UIView {
    private let session = AVCaptureSession()
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    func start() {
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev) else { return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
}

// MARK: - FILE PICKER

import UniformTypeIdentifiers
struct DocumentPicker: UIViewControllerRepresentable {
    var onPicked: (String?) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = false
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(onPicked: onPicked) }
    final class Coord: NSObject, UIDocumentPickerDelegate {
        let onPicked: (String?) -> Void
        init(onPicked: @escaping (String?) -> Void) { self.onPicked = onPicked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let u = urls.first else { onPicked(nil); return }
            onPicked(try? String(contentsOf: u, encoding: .utf8))
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPicked(nil) }
    }
}

// MARK: - BLUR

struct VisualEffectBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - EXTERNAL DISPLAY (GLASSES)

final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()
    private var window: UIWindow?
    private var host: UIHostingController<ExternalOverlayView>?
    private var source: () -> String = { "…" }
    private var cfg: (font: CGFloat, hc: Bool) = (28, true)

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateScreens),
                                               name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateScreens),
                                               name: UIScreen.didDisconnectNotification, object: nil)
        attach()
    }

    func setOverlaySource(_ s: @escaping () -> String) { source = s }
    func push(text: String, fontSize: CGFloat, highContrast: Bool) {
        cfg = (fontSize, highContrast)
        host?.rootView.model.text = text
        host?.rootView.model.fontSize = fontSize
        host?.rootView.model.highContrast = highContrast
    }

    @objc private func updateScreens() { attach() }

    private func attach() {
        guard let ext = UIScreen.screens.dropFirst().first else {
            window = nil; host = nil; return
        }
        let model = ExternalOverlayModel(text: source(), fontSize: cfg.font, highContrast: cfg.hc)
        let view = ExternalOverlayView(model: model)
        let h = UIHostingController(rootView: view)
        let w = UIWindow(frame: ext.bounds)
        w.screen = ext
        w.rootViewController = h
        w.isHidden = false
        window = w
        host = h
    }
}

final class ExternalOverlayModel: ObservableObject {
    @Published var text: String
    @Published var fontSize: CGFloat
    @Published var highContrast: Bool
    init(text: String, fontSize: CGFloat, highContrast: Bool) {
        self.text = text; self.fontSize = fontSize; self.highContrast = highContrast
    }
}

struct ExternalOverlayView: View {
    @ObservedObject var model: ExternalOverlayModel
    var body: some View {
        ZStack {
            Color.black.opacity(0.02)
            Text(model.text)
                .font(.system(size: model.fontSize, weight: .bold))
                .foregroundColor(model.highContrast ? .white : .primary)
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(model.highContrast ? .black.opacity(0.6) : .clear))
                .padding()
        }.ignoresSafeArea()
    }
}
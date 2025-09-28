import SwiftUI
import AVFoundation
import Combine

@main
struct GlassTextOverlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { ExternalDisplayManager.shared.start() }
        }
    }
}

final class OverlayModel: ObservableObject {
    @Published var overlayText: String = "Load a .txt file to display"
    @Published var fontSize: CGFloat = 28
    @Published var isHighContrast = true
    @Published var textAlignment: TextAlignment = .center
    @Published var showBackgroundBlur = true
}

struct ContentView: View {
    @StateObject private var model = OverlayModel()
    @State private var showingPicker = false
    
    var body: some View {
        ZStack {
            CameraView()
                .ignoresSafeArea()
            
            // Overlay card
            VStack {
                Spacer()
                Text(model.overlayText)
                    .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(model.textAlignment)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if model.showBackgroundBlur {
                                VisualEffectBlur()
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(model.isHighContrast ? Color.black.opacity(0.55) : Color.clear)
                            }
                        }
                    )
                    .foregroundColor(model.isHighContrast ? .white : .primary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Load .txt") { showingPicker = true }
                Slider(value: $model.fontSize, in: 16...64) { Text("Font") }
                    .frame(width: 150)
                Toggle("HC", isOn: $model.isHighContrast).toggleStyle(.button)
                Toggle("Blur", isOn: $model.showBackgroundBlur).toggleStyle(.button)
                Menu("Align") {
                    Button("Left") { model.textAlignment = .leading }
                    Button("Center") { model.textAlignment = .center }
                    Button("Right") { model.textAlignment = .trailing }
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { text in
                if let text { model.overlayText = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                ExternalDisplayManager.shared.push(text: model.overlayText,
                                                   fontSize: model.fontSize,
                                                   highContrast: model.isHighContrast)
            }
        }
        .onChange(of: model.fontSize) { _, _ in ExternalDisplayManager.shared.push(text: model.overlayText, fontSize: model.fontSize, highContrast: model.isHighContrast) }
        .onChange(of: model.isHighContrast) { _, _ in ExternalDisplayManager.shared.push(text: model.overlayText, fontSize: model.fontSize, highContrast: model.isHighContrast) }
        .onChange(of: model.overlayText) { _, _ in ExternalDisplayManager.shared.push(text: model.overlayText, fontSize: model.fontSize, highContrast: model.isHighContrast) }
        .onAppear {
            ExternalDisplayManager.shared.setOverlaySource { model.overlayText }
        }
    }
}

// MARK: - Camera Preview

struct CameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = CameraPreview()
        view.startSession()
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class CameraPreview: UIView {
    private let session = AVCaptureSession()
    private let layerPreview = AVCaptureVideoPreviewLayer()
    
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    
    func startSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        layerPreview.session = session
        layerPreview.videoGravity = .resizeAspectFill
        (layer as? AVCaptureVideoPreviewLayer)?.session = session
        (layer as? AVCaptureVideoPreviewLayer)?.videoGravity = .resizeAspectFill
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
}

// MARK: - Document Picker (Files -> .txt)

struct DocumentPicker: UIViewControllerRepresentable {
    var onPicked: (String?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)
        vc.allowsMultipleSelection = false
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coord { Coord(onPicked: onPicked) }
    final class Coord: NSObject, UIDocumentPickerDelegate {
        let onPicked: (String?) -> Void
        init(onPicked: @escaping (String?) -> Void) { self.onPicked = onPicked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onPicked(nil); return }
            do { onPicked(try String(contentsOf: url, encoding: .utf8)) }
            catch { onPicked("⚠️ Could not read file.") }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPicked(nil) }
    }
}

// MARK: - External Display (glasses) mirroring

final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()
    private var window: UIWindow?
    private var hosting: UIHostingController<ExternalOverlayView>?
    private var latestText: () -> String = { "…" }
    private var lastConfig: (font: CGFloat, hc: Bool) = (28, true)
    
    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreensChanged),
                                               name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreensChanged),
                                               name: UIScreen.didDisconnectNotification, object: nil)
        attachIfAvailable()
    }
    
    func setOverlaySource(_ source: @escaping () -> String) { latestText = source }
    
    func push(text: String, fontSize: CGFloat, highContrast: Bool) {
        lastConfig = (fontSize, highContrast)
        hosting?.rootView.model.text = text
        hosting?.rootView.model.fontSize = fontSize
        hosting?.rootView.model.highContrast = highContrast
    }
    
    @objc private func handleScreensChanged() { attachIfAvailable() }
    
    private func attachIfAvailable() {
        guard UIScreen.screens.count > 1, let ext = UIScreen.screens.dropFirst().first else {
            window = nil; hosting = nil; return
        }
        let model = ExternalOverlayModel(text: latestText(), fontSize: lastConfig.font, highContrast: lastConfig.hc)
        let root = ExternalOverlayView(model: model)
        let host = UIHostingController(rootView: root)
        let win = UIWindow(frame: ext.bounds)
        win.screen = ext
        win.rootViewController = host
        win.isHidden = false
        window = win
        hosting = host
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
            Color.black.opacity(0.02) // nearly transparent
            Text(model.text)
                .font(.system(size: model.fontSize, weight: .bold))
                .foregroundColor(model.highContrast ? .white : .primary)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(model.highContrast ? Color.black.opacity(0.6) : Color.clear)
                )
                .padding()
        }.ignoresSafeArea()
    }
}

// MARK: - Simple blur view

struct VisualEffectBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
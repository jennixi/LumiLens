import SwiftUI

struct ContentView: View {
    @StateObject var vm = AppViewModel()   // keep your existing VM for settings saving
    @State private var showSaveSheet = false
    
    // AI reply state
    @State private var happyLine: String = "…"
    @State private var neutralLine: String = "…"
    @State private var upsetLine: String = "…"
    
    // We'll create a provider at runtime using whatever key is already in settings.
    @State private var provider: DialogueProvider? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Settings row (Pi IP only)
                    HStack {
                        TextField("Pi IP (e.g., 172.20.10.5)", text: $vm.settings.piIP)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Save") { vm.saveSettings() }
                            .buttonStyle(.bordered)
                    }
                    
                    // ——— Profiles ———
                    GroupBox("Profiles") {
                        VStack(spacing: 12) {
                            ProfileCard(name: "Jennifer", hearts: 4)
                            ProfileCard(name: "Eva",       hearts: 3)
                            ProfileCard(name: "Sema",      hearts: 5)
                            ProfileCard(name: "Susan",     hearts: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // ——— AI Replies ———
                    GroupBox("AI Replies") {
                        VStack(spacing: 12) {
                            AIReplyRow(
                                title: "Happy",
                                imageName: "cathappy",
                                text: happyLine,
                                onRefresh: { Task { await generate(.happy) } }
                            )
                            AIReplyRow(
                                title: "Neutral",
                                imageName: "catneutral",
                                text: neutralLine,
                                onRefresh: { Task { await generate(.neutral) } }
                            )

                            AIReplyRow(
                                title: "Upset",
                                imageName: "catangry",
                                text: upsetLine,
                                onRefresh: { Task { await generate(.upset) } }
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("LumiLens Demo")
            .onAppear {
                // Build a provider using the (possibly empty) key already in settings.
                provider = GeminiDialogueProvider(apiKey: vm.settings.geminiAPIKey)
                // Prime initial lines
                Task { await refreshAll() }
            }
        }
    }
    
    // MARK: - AI helpers
    private func refreshAll() async {
        await generate(.happy)
        await generate(.neutral)
        await generate(.upset)
    }
    
    private func generate(_ bucket: EmotionBucket) async {
        guard let provider else { return }
        do {
            let line: String
            switch bucket {
            case .happy:
                line = try await provider.line(forEmotion: "happy")
                await MainActor.run { happyLine = line }
            case .neutral:
                line = try await provider.line(forEmotion: "neutral")
                await MainActor.run { neutralLine = line }
            case .upset:
                line = try await provider.line(forEmotion: "sad") // grouped as "upset"
                await MainActor.run { upsetLine = line }
            }
        } catch {
            await MainActor.run {
                switch bucket {
                case .happy:   happyLine = "Couldn't load—try again."
                case .neutral: neutralLine = "Couldn't load—try again."
                case .upset:   upsetLine = "Couldn't load—try again."
                }
            }
        }
    }
}

// MARK: - UI Pieces

private struct ProfileCard: View {
    let name: String
    let hearts: Int  // 0...5
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                HeartMeterView(value: hearts)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HeartMeterView: View {
    let value: Int // 0...5
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "heart.fill" : "heart")
                    .foregroundStyle(i <= value ? .red : .secondary)
            }
            Text("\(value)/5")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }
}

private struct AIReplyRow: View {
    let title: String
    let imageName: String
    let text: String
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
    }
}

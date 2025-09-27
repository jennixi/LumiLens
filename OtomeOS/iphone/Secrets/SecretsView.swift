import SwiftUI

struct SecretsView: View {
    private let acct = "otome_gemini_key"
    @State private var key: String = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Google Gemini API Key").font(.headline)
            TextEditor(text: $key).frame(height: 120).border(.gray)
            HStack {
                Button("Save") {
                    saved = KeychainHelper.shared.save(
                        key.trimmingCharacters(in: .whitespacesAndNewlines),
                        for: acct
                    )
                }.buttonStyle(.borderedProminent)

                Button("Clear") {
                    KeychainHelper.shared.delete(account: acct)
                    key = ""; saved = false
                }.buttonStyle(.bordered)
            }
            if saved { Text("Saved ✅").foregroundColor(.green) }
        }
        .padding()
        .onAppear {
            if let existing = KeychainHelper.shared.read(for: acct) {
                key = existing; saved = true
            }
        }
    }
}
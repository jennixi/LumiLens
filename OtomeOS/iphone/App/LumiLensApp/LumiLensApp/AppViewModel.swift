import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    // Persisted settings + people
    @Published var settings: AppSettings
    @Published var people: [Person]

    // Simple status fields (safe stubs for older UI)
    @Published var statusText: String = "Idle"
    @Published var currentName: String = ""
    @Published var currentEmotion: String = ""
    @Published var currentProgress: Int = 0
    @Published var unknownEmbedding: [Double]? = nil
    @Published var isPolling: Bool = false

    private let store: Store
    private var pi: PiClient?

    init(store: Store = .shared) {
        self.store = store
        self.settings = store.loadSettings()
        self.people = store.loadPeople()
        rebuildClients()
    }

    // Save + rebuild clients when settings change
    func saveSettings() {
        store.saveSettings(settings)
        rebuildClients()
    }

    func rebuildClients() {
        if !settings.piIP.isEmpty {
            pi = PiClient(baseIP: settings.piIP)
        } else {
            pi = nil
        }
    }

    // --- Stubs used by the older ContentView (no-ops so it compiles) ---
    func startPolling() { isPolling = true }
    func stopPolling()  { isPolling = false }
    func finalizeSessionIfNoFace(for _: Int) { /* no-op */ }

    func saveUnknownAs(name: String, notes: String) {
        let p = Person(name: name, notes: notes, embeddings: [], lastProgress: 0)
        people.append(p)
        store.savePeople(people)
        unknownEmbedding = nil
    }

    func mergeEmbeddingInto(person _: Person) {
        unknownEmbedding = nil
    }
}

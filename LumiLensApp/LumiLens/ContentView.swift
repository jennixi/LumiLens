import SwiftUI

struct ContentView: View {
    @StateObject var vm = AppViewModel()
    @State private var newName: String = ""
    @State private var newNotes: String = ""
    @State private var showSaveSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Settings row
                HStack {
                    TextField("Pi IP (e.g., 172.20.10.5)", text: $vm.settings.piIP)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Save") { vm.saveSettings() }
                        .buttonStyle(.bordered)
                }
                
                HStack {
                    SecureField("Gemini API Key (optional for mock)", text: $vm.settings.geminiAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Save") { vm.saveSettings() }
                        .buttonStyle(.bordered)
                }
                
                // Live status
                GroupBox("Live") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status: \(vm.statusText)")
                        Text("Name: \(vm.currentName)")
                        Text("Emotion: \(vm.currentEmotion)")
                        Text("Progress: \(vm.currentProgress)%")
                        HStack {
                            Button(vm.isPolling ? "Stop" : "Start") {
                                vm.isPolling ? vm.stopPolling() : vm.startPolling()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Finalize Session") {
                                vm.finalizeSessionIfNoFace(for: 10)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Unknown face flow
                if vm.unknownEmbedding != nil {
                    GroupBox("Unknown Face") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $newName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Notes", text: $newNotes)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            HStack {
                                Button("Save as New") {
                                    vm.saveUnknownAs(name: newName, notes: newNotes)
                                    newName = ""; newNotes = ""
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Menu("Merge into…") {
                                    ForEach(vm.people) { person in
                                        Button(person.name) {
                                            vm.mergeEmbeddingInto(person: person)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // People list
                GroupBox("People") {
                    if vm.people.isEmpty {
                        Text("No profiles yet.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(vm.people) { p in
                                VStack(alignment: .leading) {
                                    Text(p.name).font(.headline)
                                    if !p.notes.isEmpty { Text(p.notes).font(.subheadline) }
                                    Text("Last progress: \(p.lastProgress)%")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 220)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pi Companion")
            .onAppear { vm.rebuildClients() }
        }
    }
}

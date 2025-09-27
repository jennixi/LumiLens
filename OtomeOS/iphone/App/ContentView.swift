import SwiftUI

struct ContentView: View {
    @StateObject var server = WebServerManager()
    @State private var showSecrets = false

    var body: some View {
        VStack(spacing: 12) {
            Text(server.isRunning ? "Server RUNNING" : "Server STOPPED")
                .foregroundColor(server.isRunning ? .green : .red)

            HStack {
                Button(server.isRunning ? "Stop" : "Start") {
                    server.isRunning ? server.stop() : server.start()
                }.buttonStyle(.borderedProminent)

                Button("Settings") { showSecrets = true }
                    .buttonStyle(.bordered)
            }

            ScrollView {
                ForEach(server.log, id:\.self) { Text($0).font(.footnote).monospaced() }
            }
        }
        .sheet(isPresented: $showSecrets) { SecretsView() }
    }
}
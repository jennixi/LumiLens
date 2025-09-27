import SwiftUI

struct ContentView: View {
    @StateObject var server = WebServerManager()
    var body: some View {
        VStack(spacing: 12) {
            Text(server.isRunning ? "Server RUNNING" : "Server STOPPED")
                .foregroundColor(server.isRunning ? .green : .red)
            Text("IP: \(server.ip):\(server.port)")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Button(server.isRunning ? "Stop" : "Start") {
                    server.isRunning ? server.stop() : server.start()
                }.buttonStyle(.borderedProminent)
                Button("Clear Log") { server.log.removeAll() }.buttonStyle(.bordered)
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(server.log, id:\.self) { Text($0).font(.footnote).monospaced() }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .navigationTitle("OtomePhone")
    }
}
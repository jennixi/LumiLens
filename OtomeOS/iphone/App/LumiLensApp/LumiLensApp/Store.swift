import Foundation

final class Store {
    static let shared = Store()
    private init() {}
    
    private let peopleURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("people.json")
    }()
    private let settingsURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("settings.json")
    }()
    
    func loadPeople() -> [Person] {
        guard let data = try? Data(contentsOf: peopleURL) else { return [] }
        return (try? JSONDecoder().decode([Person].self, from: data)) ?? []
    }
    func savePeople(_ people: [Person]) {
        if let data = try? JSONEncoder().encode(people) {
            try? data.write(to: peopleURL, options: .atomic)
        }
    }
    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return s
    }
    func saveSettings(_ s: AppSettings) {
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }
}

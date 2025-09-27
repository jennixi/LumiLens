import Foundation

final class FaceStore {
    static let shared = FaceStore()
    private let url: URL
    private let q = DispatchQueue(label: "FaceStore")
    private(set) var profiles: [FaceProfile] = []

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = docs.appendingPathComponent("faces.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([FaceProfile].self, from: data) {
            profiles = arr
        } else { profiles = [] }
    }

    func save() {
        q.sync {
            let data = try? JSONEncoder().encode(profiles)
            try? data?.write(to: url, options: .atomic)
        }
    }

    func enroll(name: String, note: String, embedding: [Float]) {
        profiles.append(.init(id: .init(), name: name, note: note, embedding: embedding, addedAt: .init()))
        save()
    }

    func bestMatch(for emb: [Float], threshold: Float = 0.80) -> FaceMatch? {
        var best: (FaceProfile, Float)? = nil
        for p in profiles {
            let s = cosineSimilarity(p.embedding, emb)
            if s > (best?.1 ?? -1) { best = (p, s) }
        }
        if let (p, s) = best, s >= threshold { return .init(name: p.name, note: p.note, score: s) }
        return nil
    }
}
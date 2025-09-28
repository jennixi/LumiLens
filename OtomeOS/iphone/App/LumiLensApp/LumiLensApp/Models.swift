import Foundation

struct Person: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var notes: String
    var embeddings: [[Double]]  // store multiple vectors for robustness
    var lastProgress: Int       // 0,25,50,75,100
    var updatedAt: Date = Date()
}

struct AppSettings: Codable {
    var piIP: String = ""                // e.g., "172.20.10.5"
    var geminiAPIKey: String = "AlzaSyC_zV-_JmsAwwznlGqV8YVGUALN9PmREbo"        // "YOUR_GEMINI_API_KEY"
    var similarityThreshold: Double = 0.45
}

enum ProgressImageID: String {
    case p0 = "progress_0"
    case p25 = "progress_25"
    case p50 = "progress_50"
    case p75 = "progress_75"
    case p100 = "progress_100"
    
    static func from(percent: Int) -> ProgressImageID {
        switch percent {
        case ..<25: return .p0
        case 25..<50: return .p25
        case 50..<75: return .p50
        case 75..<100: return .p75
        default: return .p100
        }
    }
}

enum EmotionBucket {
    case happy
    case neutral
    case upset
    
    static func from(label: String?) -> EmotionBucket {
        switch (label ?? "").lowercased() {
        case "happy", "surprise": return .happy
        case "angry", "disgust", "fear", "sad": return .upset
        default: return .neutral
        }
    }
}

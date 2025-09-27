import Foundation

struct FaceProfile: Codable, Equatable {
    var id: UUID
    var name: String
    var note: String
    var embedding: [Float]     // 256-D vector (Vision)
    var addedAt: Date
}

struct FaceMatch: Codable {
    let name: String
    let note: String
    let score: Float           // cosine similarity 0..1
}

enum FaceError: Error { case noFace, embedFailed }

@inline(__always)
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count else { return 0 }
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    for i in 0..<a.count { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i] }
    let den = (na.squareRoot() * nb.squareRoot())
    return den > 0 ? dot/den : 0
}
import Foundation
import Accelerate

enum EmbeddingParseError: Error { case invalid }

/// Accepts base64 or hex string from Pi and returns a [Double] vector (L2-normalized).
func parseEmbedding(_ s: String) throws -> [Double] {
    // Try base64 first
    if let b64 = Data(base64Encoded: s) {
        return normalize(bytesToDoubles(b64))
    }
    // Fallback: hex
    let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count % 2 == 0 else { throw EmbeddingParseError.invalid }
    var data = Data(capacity: cleaned.count/2)
    var idx = cleaned.startIndex
    while idx < cleaned.endIndex {
        let next = cleaned.index(idx, offsetBy: 2)
        let byteStr = cleaned[idx..<next]
        guard let b = UInt8(byteStr, radix: 16) else { throw EmbeddingParseError.invalid }
        data.append(b)
        idx = next
    }
    return normalize(bytesToDoubles(data))
}

private func bytesToDoubles(_ data: Data) -> [Double] {
    // assume float32 little-endian array (most common for embeddings)
    let count = data.count / 4
    var arr = [Float](repeating: 0, count: count)
    _ = arr.withUnsafeMutableBytes { data.copyBytes(to: $0) }
    return arr.map { Double($0) }
}

private func normalize(_ v: [Double]) -> [Double] {
    let norm = sqrt(v.reduce(0) { $0 + $1*$1 })
    guard norm > 0 else { return v }
    return v.map { $0 / norm }
}

func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, a.count > 0 else { return -1 }
    var dot: Double = 0
    vDSP_dotprD(a, 1, b, 1, &dot, vDSP_Length(a.count))
    // a and b are normalized, so dot is cosine directly
    return dot
}

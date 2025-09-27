import Foundation
import Vision
import UIKit
import CoreML

/// iOS 17+ Vision face embedding
func faceEmbedding(from imageData: Data) async throws -> [Float] {
    guard let cg = UIImage(data: imageData)?.cgImage else { throw FaceError.embedFailed }
    let req = VNGenerateFaceEmbeddingRequest()
    let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
    try handler.perform([req])
    guard let obs = req.results?.first as? VNFaceObservation,
          let ml = obs.faceEmbedding else { throw FaceError.noFace }
    return ml.toFloatArray()
}

private extension MLMultiArray {
    func toFloatArray() -> [Float] {
        let count = self.count
        var out = [Float](repeating: 0, count: count)
        self.dataPointer.withMemoryRebound(to: Float.self, capacity: count) {
            out.assign(from: $0, count: count)
        }
        return out
    }
}
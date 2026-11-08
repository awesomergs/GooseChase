//
//  VisionMatcher.swift  ·  OWNER: Person A (Vision)
//  Working basics so the team can start. Tune the thresholds on real objects at the venue.
//

import UIKit
import Vision

nonisolated enum VisionMatcher {

    /// Creator side: turn a reference photo into an archived feature print to store on a Checkpoint.
    static func makeReferencePrint(from image: UIImage) throws -> Data {
        let observation = try featurePrint(for: image)
        return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    /// Player side: distance from a photo/frame to the closest reference print. Smaller = more similar.
    static func bestDistance(from image: UIImage, to references: [Data]) throws -> Float {
        let candidate = try featurePrint(for: image)
        var best = Float.greatestFiniteMagnitude
        for data in references {
            guard let ref = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: data) else { continue }
            var distance: Float = 0
            try candidate.computeDistance(&distance, to: ref)
            best = min(best, distance)
        }
        return best
    }

    /// Maps a feature-print distance to a 0...1 "match" score for the ring.
    /// TODO(A): tune `strong`/`weak` by testing real objects. These are starting guesses.
    static func score(forDistance d: Float, strong: Float = 0.45, weak: Float = 1.0) -> Double {
        if d <= strong { return 1 }
        if d >= weak { return 0 }
        return Double((weak - d) / (weak - strong))
    }

    // MARK: - Private

    private static func featurePrint(for image: UIImage) throws -> VNFeaturePrintObservation {
        guard let cg = image.cgImage else { throw MatchError.noImage }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation)
        try handler.perform([request])
        guard let result = request.results?.first else { throw MatchError.noResult }
        return result
    }

    enum MatchError: Error { case noImage, noResult }
}

private extension UIImage {
    nonisolated var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

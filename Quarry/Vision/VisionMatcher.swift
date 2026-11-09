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
    /// Scores several views of the frame (whole frame, center crop, and a crop around the most
    /// eye-catching object) and keeps the best, so a player standing further back or in front of a
    /// different background still matches. Reference prints are unchanged (whole photo).
    static func bestDistance(from image: UIImage, to references: [Data]) throws -> Float {
        let refs = references.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0)
        }
        guard !refs.isEmpty else { return .greatestFiniteMagnitude }
        let candidates = try candidatePrints(for: image)
        guard !candidates.isEmpty else { throw MatchError.noResult }
        var best = Float.greatestFiniteMagnitude
        for candidate in candidates {
            for ref in refs {
                var distance: Float = 0
                try candidate.computeDistance(&distance, to: ref)
                best = min(best, distance)
            }
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

    /// Feature prints for the whole frame, a center crop, and (if Vision finds one) the main object.
    private static func candidatePrints(for image: UIImage) throws -> [VNFeaturePrintObservation] {
        guard let cg = image.cgImage else { throw MatchError.noImage }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation)
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        var regions: [CGRect] = [unit, CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)]

        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        if (try? handler.perform([saliency])) != nil,
           let object = saliency.results?.first?.salientObjects?.max(by: { $0.confidence < $1.confidence }) {
            let box = object.boundingBox
            let padded = box.insetBy(dx: -box.width * 0.15, dy: -box.height * 0.15).intersection(unit)
            // Skip tiny specks and boxes that are basically the whole frame.
            if padded.width >= 0.15, padded.height >= 0.15, padded.width * padded.height < 0.85 {
                regions.append(padded)
            }
        }

        let requests = regions.map { region -> VNGenerateImageFeaturePrintRequest in
            let request = VNGenerateImageFeaturePrintRequest()
            request.regionOfInterest = region
            return request
        }
        try handler.perform(requests)
        return requests.compactMap { $0.results?.first }
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

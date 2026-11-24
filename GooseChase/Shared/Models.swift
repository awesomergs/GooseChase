//
//  Models.swift  ·  SHARED CONTRACT. Change only after telling the team.
//

import Foundation
import SwiftData
import CoreLocation

enum CheckpointKind: String, Codable, CaseIterable {
    case exactMatch   // photograph THIS specific thing (Vision feature print)
    case object       // photograph any thing of a category (Vision classification)
}

@Model
final class Hunt {
    var title: String
    var createdAt: Date
    /// Stable ID shared across phones. Imports with the same shareID update instead of duplicating,
    /// and a race is identified by it.
    var shareID: UUID = UUID()
    /// Who made it ("Rohan"). Shown on the join screen.
    var hostName: String = ""
    /// True for hunts received from someone else (joined or AirDropped). They appear under
    /// "Your games" in the Join tab, never in Create / Host.
    var isJoined: Bool = false
    /// When this phone last finished the hunt, and its best total time (seconds).
    var lastPlayedAt: Date?
    var bestTime: Double?
    @Relationship(deleteRule: .cascade, inverse: \Checkpoint.hunt)
    var checkpoints: [Checkpoint] = []

    init(title: String) {
        self.title = title
        self.createdAt = .now
    }

    /// Checkpoints in play order.
    var orderedCheckpoints: [Checkpoint] {
        checkpoints.sorted { $0.order < $1.order }
    }

    /// A hunt can be played only if it has checkpoints and every one has a reference photo
    /// (exactMatch) or a target label (object).
    var isPlayable: Bool {
        !checkpoints.isEmpty && checkpoints.allSatisfy(\.isReady)
    }
}

@Model
final class Checkpoint {
    var order: Int
    var clue: String
    var kindRaw: String
    /// Archived Vision feature prints of the creator's reference photos (exactMatch).
    var referencePrints: [Data] = []
    /// Small JPEG of the first reference photo, for showing a thumbnail.
    @Attribute(.externalStorage) var thumbnail: Data?
    /// Vision classification label to look for (object), e.g. "bicycle".
    var targetLabel: String?
    var hunt: Hunt?

    // MARK: Location (optional; a checkpoint without coordinates is camera-only)
    var latitude: Double?
    var longitude: Double?
    /// How close (in meters) the player must be for the checkpoint to count as "here".
    var radiusMeters: Double = 40
    /// If true, the camera only clears when the player is inside the radius
    /// (skipped in Demo Mode). If false, location is just a hot/cold guide.
    var requiresLocation: Bool = false

    init(order: Int, clue: String, kind: CheckpointKind) {
        self.order = order
        self.clue = clue
        self.kindRaw = kind.rawValue
    }

    var kind: CheckpointKind {
        get { CheckpointKind(rawValue: kindRaw) ?? .exactMatch }
        set { kindRaw = newValue.rawValue }
    }

    /// Ready to play: has what the camera needs to verify it.
    var isReady: Bool {
        switch kind {
        case .exactMatch: !referencePrints.isEmpty
        case .object: !(targetLabel ?? "").isEmpty
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        get {
            guard let latitude, let longitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }
}

//
//  Models.swift  ·  SHARED CONTRACT. Change only after telling the team.
//

import Foundation
import SwiftData

enum CheckpointKind: String, Codable, CaseIterable {
    case exactMatch   // photograph THIS specific thing (Vision feature print)
    case object       // photograph any thing of a category (Vision classification)
}

@Model
final class Hunt {
    var title: String
    var createdAt: Date
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

    init(order: Int, clue: String, kind: CheckpointKind) {
        self.order = order
        self.clue = clue
        self.kindRaw = kind.rawValue
    }

    var kind: CheckpointKind {
        get { CheckpointKind(rawValue: kindRaw) ?? .exactMatch }
        set { kindRaw = newValue.rawValue }
    }
}

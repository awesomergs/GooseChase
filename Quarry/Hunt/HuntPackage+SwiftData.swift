//
//  HuntPackage+SwiftData.swift  ·  OWNER: Person B
//  Converts between HuntPackage (wire format) and the SwiftData model.
//

import Foundation
import SwiftData

extension HuntPackage {
    /// Flatten a SwiftData Hunt into the wire-format package.
    init(hunt: Hunt) {
        self.init(
            shareID: hunt.shareID,
            title: hunt.title,
            hostName: hunt.hostName,
            checkpoints: hunt.orderedCheckpoints.map { cp in
                CheckpointPackage(
                    order: cp.order,
                    clue: cp.clue,
                    kindRaw: cp.kindRaw,
                    referencePrints: cp.referencePrints,
                    thumbnail: cp.thumbnail,
                    targetLabel: cp.targetLabel,
                    latitude: cp.latitude,
                    longitude: cp.longitude,
                    radiusMeters: cp.radiusMeters,
                    requiresLocation: cp.requiresLocation
                )
            }
        )
    }

    /// Find an existing Hunt with the same shareID and replace its title and checkpoints,
    /// or insert a new one. Returns the Hunt (inserted or updated).
    @discardableResult
    func importHunt(into context: ModelContext) -> Hunt {
        let shareID = self.shareID
        let descriptor = FetchDescriptor<Hunt>(
            predicate: #Predicate { $0.shareID == shareID }
        )

        if let existing = (try? context.fetch(descriptor))?.first {
            existing.title = self.title
            existing.hostName = self.hostName
            for cp in existing.checkpoints {
                context.delete(cp)
            }
            for pkg in checkpoints {
                existing.checkpoints.append(makeCheckpoint(from: pkg, context: context))
            }
            return existing
        } else {
            let hunt = Hunt(title: self.title)
            hunt.shareID = self.shareID
            hunt.hostName = self.hostName
            context.insert(hunt)
            for pkg in checkpoints {
                hunt.checkpoints.append(makeCheckpoint(from: pkg, context: context))
            }
            return hunt
        }
    }
}

private func makeCheckpoint(from pkg: CheckpointPackage, context: ModelContext) -> Checkpoint {
    let cp = Checkpoint(
        order: pkg.order,
        clue: pkg.clue,
        kind: CheckpointKind(rawValue: pkg.kindRaw) ?? .exactMatch
    )
    cp.referencePrints = pkg.referencePrints
    cp.thumbnail = pkg.thumbnail
    cp.targetLabel = pkg.targetLabel
    cp.latitude = pkg.latitude
    cp.longitude = pkg.longitude
    cp.radiusMeters = pkg.radiusMeters
    cp.requiresLocation = pkg.requiresLocation
    context.insert(cp)
    return cp
}

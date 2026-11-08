//
//  HuntTransfer.swift  ·  OWNER: Person C
//  Hunt ⇄ HuntPackage, used by the Host lobby (send) and Join screen (save).
//  B's AirDrop sharing can call these too instead of writing its own.
//

import Foundation
import SwiftData

enum HuntTransfer {
    /// Everything another phone needs to play this hunt.
    static func package(for hunt: Hunt) -> HuntPackage {
        HuntPackage(
            shareID: hunt.shareID,
            title: hunt.title,
            hostName: hunt.hostName.isEmpty ? PlayerIdentity.name : hunt.hostName,
            checkpoints: hunt.orderedCheckpoints.map { cp in
                CheckpointPackage(
                    order: cp.order, clue: cp.clue, kindRaw: cp.kindRaw,
                    referencePrints: cp.referencePrints, thumbnail: cp.thumbnail,
                    targetLabel: cp.targetLabel, latitude: cp.latitude, longitude: cp.longitude,
                    radiusMeters: cp.radiusMeters, requiresLocation: cp.requiresLocation
                )
            }
        )
    }

    /// Saves a received hunt into this phone's list. Joining the same hunt twice updates it
    /// instead of making a duplicate (matched by shareID).
    @discardableResult
    static func save(_ package: HuntPackage, into context: ModelContext) -> Hunt {
        let id = package.shareID
        let existing = try? context.fetch(FetchDescriptor<Hunt>(predicate: #Predicate { $0.shareID == id })).first

        let hunt: Hunt
        if let existing {
            hunt = existing
            for old in hunt.checkpoints { context.delete(old) }
            hunt.checkpoints = []
        } else {
            hunt = Hunt(title: package.title)
            hunt.shareID = package.shareID
            context.insert(hunt)
        }
        hunt.title = package.title
        hunt.hostName = package.hostName

        for item in package.checkpoints.sorted(by: { $0.order < $1.order }) {
            let cp = Checkpoint(order: item.order, clue: item.clue,
                                kind: CheckpointKind(rawValue: item.kindRaw) ?? .exactMatch)
            cp.referencePrints = item.referencePrints
            cp.thumbnail = item.thumbnail
            cp.targetLabel = item.targetLabel
            cp.latitude = item.latitude
            cp.longitude = item.longitude
            cp.radiusMeters = item.radiusMeters
            cp.requiresLocation = item.requiresLocation
            cp.hunt = hunt
            hunt.checkpoints.append(cp)
        }
        do { try context.save() } catch { print("⚠️ Saving joined hunt failed:", error) }
        return hunt
    }
}

//
//  DemoData.swift  ·  OWNER: Person B
//  A seeded hunt so everyone can test before the create flow exists.
//

import SwiftData

enum DemoData {
    static func seedIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Hunt>())) ?? 0
        guard existing == 0 else { return }

        let hunt = Hunt(title: "Birthday Hunt")
        let clues = [
            "Find the thing that keeps the milk cold.",
            "Find something with wheels.",
            "Find the cup with the blue stripe."
        ]
        for (i, clue) in clues.enumerated() {
            let cp = Checkpoint(order: i, clue: clue, kind: i == 1 ? .object : .exactMatch)
            if i == 1 { cp.targetLabel = "wheel" }
            cp.hunt = hunt
            hunt.checkpoints.append(cp)
        }
        context.insert(hunt)
    }
}

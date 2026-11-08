//
// VerifyCameraView.swift · OWNER: Person A
//
import SwiftUI
import SwiftData

struct VerifyCameraView: View {
    let checkpoint: Checkpoint
    let onCleared: () -> Void

    var body: some View {
        CameraCaptureView(
            title: checkpoint.clue,
            message: "Frame the object and hold steady.",
            referencePrints: checkpoint.referencePrints
        ) { _ in
            onCleared()
        }
    }
}

#Preview {
    VerifyCameraView(checkpoint: Checkpoint(order: 0, clue: "Find the blue cup.", kind: .exactMatch), onCleared: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

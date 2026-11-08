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
            message: "Take a photo to check the camera. Checkpoint verification is not available yet."
        ) { _ in
            // A photo alone is not proof of a match. Only successful Vision
            // verification may call onCleared in the next milestone.
        }
    }
}

#Preview {
    VerifyCameraView(checkpoint: Checkpoint(order: 0, clue: "Find the blue cup.", kind: .exactMatch), onCleared: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

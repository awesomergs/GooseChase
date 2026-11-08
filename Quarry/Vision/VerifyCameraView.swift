//
//  VerifyCameraView.swift  ·  OWNER: Person A (Vision)
//  STUB so Person B can wire up the flow now. Replace the body with the real camera,
//  confidence ring and auto-capture, but KEEP THE SAME INITIALIZER (checkpoint + onCleared).
//

import SwiftUI

struct VerifyCameraView: View {
    let checkpoint: Checkpoint
    let onCleared: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Camera goes here")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(checkpoint.clue)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Pretend cleared") { onCleared() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

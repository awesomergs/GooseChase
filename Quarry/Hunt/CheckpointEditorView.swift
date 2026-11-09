//
//  CheckpointEditorView.swift  ·  OWNER: Person B (hunt flow)
//  Form editor for one Checkpoint: set the clue and capture up to 3 reference photos.
//  Calling VisionMatcher.makeReferencePrint on a background task keeps Vision off the main thread.
//

import SwiftUI
import SwiftData

struct CheckpointEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    @Bindable var checkpoint: Checkpoint

    @State private var capturedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingPicker = false

    var body: some View {
        Form {
            // MARK: Clue
            Section("01 · Write the clue") {
                TextField("Describe what to find", text: $checkpoint.clue, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .padding(.vertical, 8)
            }
            .listRowBackground(theme.card)

            // MARK: Reference photos
            Section {
                // Thumbnail strip — shows images captured in this session.
                // On re-open the first slot is seeded from checkpoint.thumbnail (.onAppear below).
                if !capturedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: QuarryTheme.thumbnailRadius))
                                    .accessibilityLabel("Reference photo \(index + 1)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if capturedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(theme.accent)
                            .accessibilityHidden(true)
                        Text("Give the camera something to recognize.")
                            .font(QuarryTheme.heading)
                        Text("Photograph the object from a few angles. Players will match it with their camera.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }

                // Processing indicator while Vision is running
                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Processing photo…")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                } else if checkpoint.referencePrints.count < 3 {
                    Button {
                        showingPicker = true
                    } label: {
                        Label(
                            "Add photo",
                            systemImage: capturedImages.isEmpty ? "camera" : "plus"
                        )
                    }
                }

                // Inline error message (never fatalError per SPEC §11)
                if let message = errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

            } header: {
                Text("02 · Add reference photos")
            } footer: {
                Text("\(checkpoint.referencePrints.count) of 3 added. Try a few angles so the camera can recognize it.")
                    .foregroundStyle(theme.secondaryText)
            }
            .listRowBackground(theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.primaryText)
        .tint(theme.accent)
        .navigationTitle("Checkpoint \(checkpoint.order + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPicker) {
            CameraPicker { image in
                handlePickedImage(image)
            }
            .presentationBackground(theme.card)
        }
        .onAppear {
            // Seed the display with the saved thumbnail so the strip shows up on re-open.
            if capturedImages.isEmpty,
               let data = checkpoint.thumbnail,
               let image = UIImage(data: data) {
                capturedImages = [image]
            }
        }
    }

    // MARK: - Photo handling

    /// Runs the Vision feature-print computation off the main thread, then stores
    /// the result on the Checkpoint and updates local display state.
    private func handlePickedImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil

        Task {
            defer { isProcessing = false }
            do {
                // Heavy Vision work runs on a background thread (required by SPEC §11).
                let printData = try await Task.detached {
                    try VisionMatcher.makeReferencePrint(from: image)
                }.value

                // Back on the main actor: mutate SwiftData model and local state.
                checkpoint.referencePrints.append(printData)
                capturedImages.append(image)
                if checkpoint.thumbnail == nil {
                    checkpoint.thumbnail = downsizedJPEG(image)
                }
            } catch {
                errorMessage = "Couldn't process photo — try again."
                print("⚠️ VisionMatcher.makeReferencePrint failed: \(error)")
            }
        }
    }

    /// Returns a ≤300 px JPEG for use as a thumbnail. Never stores full-size images per SPEC §11.
    private func downsizedJPEG(_ image: UIImage, maxDimension: CGFloat = 300) -> Data? {
        let scale = min(maxDimension / image.size.width,
                        maxDimension / image.size.height,
                        1)
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([Hunt.self, Checkpoint.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    let cp = Checkpoint(order: 0, clue: "Find the thing that keeps the milk cold.", kind: .exactMatch)
    container.mainContext.insert(cp)
    return NavigationStack {
        CheckpointEditorView(checkpoint: cp)
    }
    .modelContainer(container)
}

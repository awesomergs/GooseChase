import SwiftUI
import SwiftData

struct HuntThumbnail: View {
    @Environment(\.colorScheme) private var colorScheme
    let data: Data?

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                theme.sand
                    .overlay {
                        Image("d f")
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .shadow(color: .black.opacity(0.45), radius: 0.75, y: 1)
                    }
            }
        }
        .frame(width: QuarryTheme.thumbnailSize, height: QuarryTheme.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: QuarryTheme.thumbnailRadius))
        .accessibilityHidden(true)
    }
}

#Preview {
    HuntThumbnail(data: nil)
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

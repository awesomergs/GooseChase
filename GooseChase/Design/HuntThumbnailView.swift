import SwiftUI

/// A hunt's thumbnail: its first checkpoint's photo, or a flag placeholder.
struct HuntThumbnailView: View {
    let data: Data?
    var size: CGFloat = 44

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            Image(systemName: "flag.fill")
                .foregroundStyle(Brand.sky)
                .frame(width: size, height: size)
                .background(Brand.sky.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.2))
        }
    }
}

#Preview {
    HuntThumbnailView(data: nil)
        .padding()
        .background(Brand.canvas)
}

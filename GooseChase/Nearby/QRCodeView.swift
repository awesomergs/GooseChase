//
//  QRCodeView.swift  ·  OWNER: Person C
//  Renders a crisp QR code for a URL (used for quarry://join?code=XXXX).
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let url: URL

    var body: some View {
        Group {
            if let image = Self.makeImage(for: url.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("QR code to join the hunt")
    }

    static func makeImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(url: RoomCode.joinURL("KQ7X"))
        .frame(width: 240, height: 240)
        .padding()
        .background(Color(.systemGroupedBackground))
}

//
//  QRScannerView.swift  ·  OWNER: Person C
//  Live QR scanner (VisionKit). Calls onCode once with the room code from a
//  quarry://join?code=XXXX QR, then the caller dismisses it.
//

import SwiftUI
import VisionKit
import Vision

struct QRScannerView: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
                    ScannerRepresentable(onCode: { code in
                        onCode(code)
                        dismiss()
                    })
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        Text("Point at the host's QR code")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect()
                            .padding(.bottom, 40)
                    }
                } else {
                    ContentUnavailableView(
                        "Can't scan here",
                        systemImage: "qrcode.viewfinder",
                        description: Text("Type the 4-letter code instead, or allow camera access in Settings.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var handled = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !handled else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let text = barcode.payloadStringValue,
                      let url = URL(string: text) else { continue }
                // Accept quarry://join?code=XXXX, or a bare 4-character code.
                let code = RoomCode.code(from: url)
                    ?? (text.count == 4 ? text.uppercased() : nil)
                if let code {
                    handled = true
                    onCode(code)
                    return
                }
            }
        }
    }
}

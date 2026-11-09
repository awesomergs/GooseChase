//
//  CameraPicker.swift  ·  OWNER: Person B (hunt flow)
//  Wraps UIImagePickerController for capturing or picking a reference photo.
//  Uses .camera on a real device; falls back to .photoLibrary in the Simulator.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.view.tintColor = UIColor(QuarryTheme(colorScheme: colorScheme).accent)
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Keep coordinator in sync with the latest environment values (e.g. dismiss action).
        context.coordinator.parent = self
        uiViewController.view.tintColor = UIColor(QuarryTheme(colorScheme: colorScheme).accent)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

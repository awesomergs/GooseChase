//
// CameraSession.swift · OWNER: Person A
//
import AVFoundation
import Foundation

// All mutable capture state is confined to queue. The session is exposed only
// so the main-thread preview layer can display it, never to configure it.
nonisolated final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Quarry.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var captureDelegate: PhotoDelegate?

    enum CameraError: Error {
        case unavailable
        case captureFailed
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    if !self.configured {
                        try self.configure()
                    }
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    guard self.session.isRunning, !self.session.isInterrupted else {
                        throw CameraError.unavailable
                    }
                    continuation.resume()
                } catch {
                    print("⚠️ Camera could not start:", error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            throw CameraError.unavailable
        }
        session.addOutput(photoOutput)
        configured = true
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capture(rotationAngle: CGFloat) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, !self.session.isInterrupted,
                      self.captureDelegate == nil,
                      let connection = self.photoOutput.connection(with: .video),
                      connection.isActive else {
                    continuation.resume(throwing: CameraError.unavailable)
                    return
                }
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                let delegate = PhotoDelegate { [weak owner = self] result in
                    guard let owner else {
                        continuation.resume(throwing: CameraError.captureFailed)
                        return
                    }
                    owner.queue.async {
                        owner.captureDelegate = nil
                        continuation.resume(with: result)
                    }
                }
                // Retain the delegate until didFinishCapture, not just processing.
                self.captureDelegate = delegate
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }
}

nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private var result: Result<Data, Error> = .failure(CameraSession.CameraError.captureFailed)
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        completion(error.map { .failure($0) } ?? result)
    }
}

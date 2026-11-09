//
// CameraSession.swift · OWNER: Person A
//
import AVFoundation
import Foundation
import CoreImage
import UIKit

// All mutable capture state is confined to queue. The session is exposed only
// so the main-thread preview layer can display it, never to configure it.
nonisolated final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Quarry.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext()
    private var latestFrame: CVPixelBuffer?
    private var latestFrameTime = ContinuousClock.now
    private var configured = false
    private var captureDelegate: PhotoDelegate?
    /// Last few live-frame scores; averaged so one lucky or blurry frame can't flip the result.
    private var recentScores: [Double] = []

    enum CameraError: Error {
        case unavailable
        case captureFailed
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    self.recentScores = []
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
        guard session.canAddOutput(videoOutput) else {
            session.removeOutput(photoOutput)
            session.removeInput(input)
            throw CameraError.unavailable
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(videoOutput)
        // Keep buffers in sensor orientation; apply the capture angle to UIImage.
        videoOutput.connection(with: .video)?.videoRotationAngle = 0
        configured = true
    }

    func stop() {
        queue.async {
            self.latestFrame = nil
            self.recentScores = []
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestFrame = CMSampleBufferGetImageBuffer(sampleBuffer)
        latestFrameTime = .now
    }

    // Both live and still comparisons run on the same serial queue, never concurrently.
    func matchScore(references: [Data], rotationAngle: CGFloat, photo: Data? = nil) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let score: Double? = try autoreleasepool {
                        guard !references.isEmpty else { return nil }
                        let image: UIImage
                        if let photo {
                            guard let decoded = UIImage(data: photo) else { throw CameraError.captureFailed }
                            image = decoded
                        } else {
                            guard self.session.isRunning, !self.session.isInterrupted,
                                  let buffer = self.latestFrame,
                                  self.latestFrameTime.duration(to: .now) < .milliseconds(400) else { return nil }
                            self.latestFrame = nil
                            let ciImage = CIImage(cvPixelBuffer: buffer)
                            guard let cgImage = self.imageContext.createCGImage(ciImage, from: ciImage.extent) else {
                                throw CameraError.captureFailed
                            }
                            let orientations: [UIImage.Orientation] = [.up, .right, .down, .left]
                            let quadrant = (Int((rotationAngle / 90).rounded()) % 4 + 4) % 4
                            image = UIImage(cgImage: cgImage, scale: 1, orientation: orientations[quadrant])
                        }
                        let raw = VisionMatcher.score(forDistance: try VisionMatcher.bestDistance(from: image, to: references))
                        // Still photos (the final check) use their own score; live frames are smoothed.
                        guard photo == nil else { return raw }
                        self.recentScores.append(raw)
                        if self.recentScores.count > 3 { self.recentScores.removeFirst() }
                        return self.recentScores.reduce(0, +) / Double(self.recentScores.count)
                    }
                    continuation.resume(returning: score)
                } catch {
                    continuation.resume(throwing: error)
                }
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

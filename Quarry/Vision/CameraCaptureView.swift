//
// CameraCaptureView.swift · OWNER: Person A
//
import AVFoundation
import SwiftUI
import SwiftData
import UIKit

/// Presents the back camera and returns one UIImage per successful shutter tap.
/// Stays open for additional photos; the caller may dismiss from onCaptured.
/// Close/cancellation never calls onCaptured. Images are not saved to Photos.
struct CameraCaptureView: View {
    var title: String = "Reference photo"
    var message: String = "Frame the object, then take a photo."
    // nil keeps reference-photo capture unchanged; an empty array blocks verification.
    var referencePrints: [Data]? = nil
    let onCaptured: (UIImage) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let cameraTheme = QuarryTheme(colorScheme: .dark)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraSession()
    @State private var isReady = false
    @State private var isCapturing = false
    @State private var isVisible = false
    @State private var accessDenied = false
    @State private var status = "Starting camera…"
    @State private var lastPhoto: UIImage?
    @State private var rotationAngle: CGFloat = 90
    @State private var generation = UUID()
    @State private var retryID = 0

    @State private var matchScore = 0.0
    @State private var matchingSince: ContinuousClock.Instant?
    @State private var lastMatchTime: ContinuousClock.Instant?
    @State private var didClear = false
    @State private var errorFeedback = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Starting threshold: 85% (distance <= 0.5325 with the helper defaults).
    // Tune with at least five real objects; this is not yet venue-calibrated.
    private let matchThreshold = 0.85

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session, isReady: isReady, captureAngle: $rotationAngle)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            if !isReady {
                CameraStatusView(status: status, accessDenied: accessDenied) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } retry: {
                    retryID += 1
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Close", systemImage: "xmark") {
                    deactivate()
                    dismiss()
                }
                .buttonStyle(.glass)
                .tint(cameraTheme.card)
            }
            .padding()
            .background(.black.opacity(reduceTransparency ? 1 : 0.8))
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let lastPhoto {
                    Image(uiImage: lastPhoto)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .accessibilityLabel("Last captured photo")
                }
                Text(referencePrints?.isEmpty == true ? "Reference photos needed" : (isReady ? message : status))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                if isReady, !status.isEmpty {
                    Text(status).font(.caption)
                }
                if referencePrints != nil {
                    Text("Match \(matchScore, format: .percent.precision(.fractionLength(0)))")
                        .font(.headline)
                    if referencePrints?.isEmpty == true {
                        Text("Add reference photos to this checkpoint before verifying.")
                            .font(.subheadline)
                    }
                }
                Button {
                    capturePhoto()
                } label: {
                    if referencePrints != nil {
                        ZStack {
                            Circle().stroke(.gray, lineWidth: 6)
                            Circle().trim(from: 0, to: matchScore)
                                .stroke(didClear ? cameraTheme.verified : cameraTheme.primaryText,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: matchScore)
                            Image(systemName: didClear ? "checkmark" : "camera.fill")
                                .font(.title)
                                .foregroundStyle(cameraTheme.primaryText)
                        }
                        .background(.black, in: .circle)
                        .frame(width: 72, height: 72)
                        .padding(6)
                    } else {
                        Label(isCapturing ? "Taking photo…" : "Take photo", systemImage: "camera.circle.fill")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .foregroundStyle(cameraTheme.onAccent)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(isCapturing ? "Verifying photo" : "Take photo")
                .disabled(!isReady || isCapturing || scenePhase != .active || didClear || referencePrints?.isEmpty == true)
            }
            .padding()
            .background(.black.opacity(reduceTransparency ? 1 : 0.8))
        }
        .foregroundStyle(.white)
        .tint(cameraTheme.accent)
        .sensoryFeedback(.success, trigger: didClear)
        .sensoryFeedback(.error, trigger: errorFeedback)
        .task(id: generation) { await monitorMatch() }
        .onAppear { isVisible = true }
        .onDisappear { deactivate() }
        .task(id: scenePhase) { await updateCamera() }
        .task(id: retryID) {
            if retryID > 0 { await updateCamera() }
        }
        .task {
            for await notification in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification, object: nil) {
                guard let session = notification.object as? AVCaptureSession, session === camera.session else { continue }
                generation = UUID()
                isReady = false
                isCapturing = false
                status = "Camera interrupted. Try again when it is available."
            }
        }
        .task {
            for await notification in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification, object: nil) {
                guard let session = notification.object as? AVCaptureSession, session === camera.session else { continue }
                if isVisible, scenePhase == .active { retryID += 1 }
            }
        }
        .task {
            for await notification in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification, object: nil) {
                guard let session = notification.object as? AVCaptureSession, session === camera.session else { continue }
                generation = UUID()
                isReady = false
                isCapturing = false
                status = "Camera unavailable. Try opening it again."
                camera.stop()
            }
        }
    }

    private func monitorMatch() async {
        matchingSince = nil
        lastMatchTime = nil
        matchScore = 0
        guard let references = referencePrints, !references.isEmpty else { return }
        let request = generation
        while !Task.isCancelled, generation == request, !didClear {
            let started = ContinuousClock.now
            if isVisible, isReady, scenePhase == .active, !isCapturing {
                do {
                    let score = try await camera.matchScore(references: references, rotationAngle: rotationAngle)
                    guard !Task.isCancelled, generation == request, isVisible, isReady,
                          scenePhase == .active, !didClear else { return }
                    if !isCapturing {
                        matchScore = score ?? 0
                        let now = ContinuousClock.now
                        // A missing frame or long gap cannot count toward a continuous hold.
                        if score != nil, matchScore >= matchThreshold {
                            if let lastMatchTime, lastMatchTime.duration(to: now) > .milliseconds(400) {
                                matchingSince = nil
                            }
                            if matchingSince == nil { matchingSince = now }
                            lastMatchTime = now
                            if let matchingSince, matchingSince.duration(to: now) >= .milliseconds(500) {
                                capturePhoto()
                            }
                        } else {
                            matchingSince = nil
                            lastMatchTime = nil
                        }
                    }
                } catch {
                    guard !Task.isCancelled, generation == request else { return }
                    matchScore = 0
                    matchingSince = nil
                    lastMatchTime = nil
                    status = "Unable to compare. Try again or retake the reference photos."
                    print("⚠️ Vision comparison failed:", error)
                }
            } else {
                matchingSince = nil
                lastMatchTime = nil
            }
            do {
                try await Task.sleep(until: started.advanced(by: .milliseconds(200)), clock: .continuous)
            } catch { return }
        }
    }

    private func updateCamera() async {
        let request = UUID()
        generation = request
        isReady = false
        isCapturing = false
        guard scenePhase == .active else {
            camera.stop()
            status = "Camera paused."
            return
        }
        status = "Starting camera…"
        var authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            authorization = AVCaptureDevice.authorizationStatus(for: .video)
        }
        guard !Task.isCancelled, generation == request, isVisible else { return }
        accessDenied = authorization == .denied
        guard authorization == .authorized else {
            status = authorization == .restricted
                ? "Camera access is restricted on this device."
                : "Allow camera access in Settings to take photos."
            camera.stop()
            return
        }
        do {
            try await camera.start()
            guard !Task.isCancelled, generation == request, isVisible else { return }
            isReady = true
            status = ""
        } catch {
            guard !Task.isCancelled, generation == request, isVisible else { return }
            status = "The back camera is unavailable. Try again on your iPhone."
        }
    }

    private func deactivate() {
        isVisible = false
        generation = UUID()
        isReady = false
        camera.stop()
    }

    private func capturePhoto() {
        guard isReady, !isCapturing, !didClear, referencePrints?.isEmpty != true else { return }
        matchingSince = nil
        isCapturing = true
        let request = generation
        let angle = rotationAngle
        Task {
            do {
                let data = try await camera.capture(rotationAngle: angle)
                guard isVisible, scenePhase == .active, generation == request else { return }
                guard let image = UIImage(data: data) else {
                    throw CameraSession.CameraError.captureFailed
                }
                if let references = referencePrints {
                    let score = try await camera.matchScore(references: references, rotationAngle: angle, photo: data) ?? 0
                    guard isVisible, scenePhase == .active, generation == request, !didClear else { return }
                    matchScore = score
                    guard score >= matchThreshold else {
                        isCapturing = false
                        status = "Not quite. Try another angle."
                        errorFeedback += 1
                        return
                    }
                    didClear = true
                }
                lastPhoto = image
                isCapturing = false
                status = "Photo captured."
                onCaptured(image)
            } catch {
                guard isVisible, generation == request else { return }
                print("⚠️ Photo capture failed:", error)
                isCapturing = false
                status = "Couldn’t capture or verify the photo. Please try again."
                errorFeedback += 1
            }
        }
    }
}

private struct CameraStatusView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let theme = QuarryTheme(colorScheme: .dark)
    let status: String
    let accessDenied: Bool
    let openSettings: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera").font(.largeTitle)
            Text(status).multilineTextAlignment(.center)
            if accessDenied {
                Button("Open Settings", action: openSettings)
                    .foregroundStyle(theme.onAccent)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Try again", action: retry)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .foregroundStyle(theme.primaryText)
        .tint(theme.accent)
        .background(.black.opacity(reduceTransparency ? 1 : 0.8), in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isReady: Bool
    @Binding var captureAngle: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        guard isReady else { return }
        view.configureRotation { angle in
            captureAngle = angle
        }
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.previewLayer.session = nil
    }
}

private final class PreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(previewLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewObservation: NSKeyValueObservation?
    private var captureObservation: NSKeyValueObservation?

    func configureRotation(onCaptureAngle: @escaping (CGFloat) -> Void) {
        guard rotationCoordinator == nil,
              let input = previewLayer.session?.inputs.first as? AVCaptureDeviceInput else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        previewObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor [weak self] in
                guard let connection = self?.previewLayer.connection,
                      connection.isVideoRotationAngleSupported(angle) else { return }
                connection.videoRotationAngle = angle
            }
        }
        captureObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            Task { @MainActor in onCaptureAngle(angle) }
        }
    }
}

#Preview("Reference capture") {
    CameraCaptureView { _ in }
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

#Preview("Camera access denied") {
    CameraStatusView(status: "Allow camera access in Settings to take photos.", accessDenied: true, openSettings: {}, retry: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

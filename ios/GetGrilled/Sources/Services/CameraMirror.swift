import AVFoundation
import SwiftUI

/// Local-only camera self-view. Deliberately has no `AVCaptureVideoDataOutput`, photo output,
/// or file output — there is no code path for a frame to leave the preview layer, let alone
/// the device. See docs/v2-technical-spec.md §5.
@MainActor
final class CameraMirrorService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private var isConfigured = false

    func requestAuthorizationIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func start() {
        Task {
            guard await requestAuthorizationIfNeeded() else {
                errorMessage = "Camera access denied — you can still practice without the self-view."
                return
            }
            configureIfNeeded()
            guard isConfigured else { return }
            errorMessage = nil
            await Task.detached(priority: .userInitiated) { [session] in
                session.startRunning()
            }.value
            isRunning = true
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            isConfigured = true
        } else {
            errorMessage = "No front camera available in this environment."
        }
        session.commitConfiguration()
    }
}

/// Thin UIViewRepresentable around AVCaptureVideoPreviewLayer — a preview surface only.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

@preconcurrency import AVFoundation
import Foundation
import Observation

/// Manages the AVCaptureSession lifecycle for the Mirror widget. Started when
/// the user opens the mirror tab; stopped when they leave it (so the camera LED
/// turns off promptly and we don't keep the device busy).
@MainActor
@Observable
final class MirrorFeature {
    enum Status: Equatable {
        case idle
        case denied
        case running
        case unavailable
    }

    private(set) var status: Status = .idle
    /// AVCaptureSession's start/stopRunning are documented thread-safe; we use
    /// `@preconcurrency import` to bypass Swift 6 Sendable checking and call
    /// them from a background queue without blocking the main actor.
    let session: AVCaptureSession = AVCaptureSession()
    private var configured = false

    func start() async {
        guard status != .running else { return }
        let granted = await Self.requestAccess()
        guard granted else {
            status = .denied
            return
        }
        if !configured {
            configureSession()
            configured = true
        }
        if !session.isRunning {
            let s = session
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    s.startRunning()
                    cont.resume()
                }
            }
        }
        status = session.isRunning ? .running : .unavailable
    }

    func stop() {
        guard session.isRunning else { return }
        let s = session
        DispatchQueue.global(qos: .userInitiated).async {
            s.stopRunning()
        }
        status = .idle
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            status = .unavailable
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            session.commitConfiguration()
            status = .unavailable
            return
        }
        session.commitConfiguration()
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
            }
        default: return false
        }
    }
}

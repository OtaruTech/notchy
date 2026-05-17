import AVFoundation
import AppKit
import SwiftUI

struct MirrorView: View {
    let feature: MirrorFeature

    var body: some View {
        VStack(spacing: 8) {
            switch feature.status {
            case .running:
                MirrorPreview(session: feature.session)
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            case .denied:
                statusBox(icon: "video.slash.fill", title: "Camera denied",
                          subtitle: "Enable in System Settings → Privacy → Camera")
            case .unavailable:
                statusBox(icon: "exclamationmark.triangle.fill", title: "No camera",
                          subtitle: "No FaceTime / built-in camera found")
            case .idle:
                statusBox(icon: "video.circle", title: "Starting…", subtitle: nil)
            }
        }
        .task {
            await feature.start()
        }
        .onDisappear {
            feature.stop()
        }
    }

    @ViewBuilder
    private func statusBox(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.6))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(width: 220, height: 124)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// NSViewRepresentable wrapper around AVCaptureVideoPreviewLayer.
private struct MirrorPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = PreviewView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.previewLayer = layer
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PreviewView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    override var wantsUpdateLayer: Bool { true }
}

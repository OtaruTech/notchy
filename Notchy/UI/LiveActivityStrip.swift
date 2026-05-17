import SwiftUI
import AppKit

/// NotchNook-style live activity strip: small album art flanks the LEFT of the
/// hardware notch, animated waveform flanks the RIGHT. Together they make the
/// physical notch appear to "grow" sideways while music plays.
///
/// Rendered when (state in .idle/.hint) AND media is playing. The center matches
/// the physical notch size (DesignTokens.notchWidth × notchHeight) so the
/// hardware notch shows through unmodified; only the wings render content.
struct LiveActivityStrip: View {
    let vm: NowPlayingVM
    /// Single-character vertical "bar" heights driven by an animation phase.
    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private let wingWidth: CGFloat = 70
    private let stripHeight: CGFloat = DesignTokens.notchHeight

    var body: some View {
        HStack(spacing: 0) {
            // LEFT wing — album art
            ZStack(alignment: .trailing) {
                Rectangle().fill(.black)  // wing background — same as notch
                artwork
                    .frame(width: stripHeight - 6, height: stripHeight - 6)
                    .padding(.trailing, 6)
            }
            .frame(width: wingWidth, height: stripHeight)
            .clipShape(
                .rect(
                    topLeadingRadius: 14,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )

            // CENTER — invisible passthrough matching the physical notch
            Color.black.frame(width: DesignTokens.notchWidth, height: stripHeight)

            // RIGHT wing — animated waveform
            ZStack(alignment: .leading) {
                Rectangle().fill(.black)
                Waveform(phase: phase, playing: vm.isPlaying)
                    .frame(width: wingWidth - 12, height: stripHeight - 12)
                    .padding(.leading, 6)
            }
            .frame(width: wingWidth, height: stripHeight)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 14,
                    style: .continuous
                )
            )
        }
        .onReceive(timer) { _ in
            if vm.isPlaying { phase += 1 }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = vm.artworkData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

/// 4-bar animated equalizer that pulses when `playing`, flat when paused.
private struct Waveform: View {
    let phase: Double
    let playing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.spring(response: 0.25, dampingFraction: 0.55), value: phase)
            }
        }
        .opacity(playing ? 1 : 0.35)
    }

    /// Pseudo-random heights driven by phase + bar index — gives a "music" feel.
    private func barHeight(for i: Int) -> CGFloat {
        let base: CGFloat = 6
        let max: CGFloat = 18
        guard playing else { return base }
        let p = phase + Double(i) * 0.7
        let v = (sin(p * 1.3) + cos(p * 2.1 + Double(i))) * 0.5 + 0.5  // 0..1
        return base + CGFloat(v) * (max - base)
    }
}

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
    let vm: NowPlayingVM?
    let timerState: TimerFeature.State
    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private let wingWidth: CGFloat = 70

    private var hasMedia: Bool { vm != nil }
    private var hasTimer: Bool {
        if case .idle = timerState { return false }
        return true
    }

    /// Live values queried at render so the strip matches THIS Mac's notch.
    private var notchW: CGFloat { ScreenGeometry.liveNotchWidth() }
    private var notchH: CGFloat { ScreenGeometry.liveNotchHeight() }

    var body: some View {
        HStack(spacing: 0) {
            // LEFT wing — album art (only if media is loaded).
            if hasMedia {
                ZStack(alignment: .trailing) {
                    Rectangle().fill(.black)
                    artwork
                        .frame(width: notchH - 8, height: notchH - 8)
                        .padding(.trailing, 6)
                }
                .frame(width: wingWidth, height: notchH)
                .clipShape(
                    .rect(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
            }

            // CENTER — invisible passthrough matching the physical notch (LIVE size).
            Color.black.frame(width: notchW, height: notchH)

            // RIGHT wing — timer takes priority (so it remains visible while music
            // is also playing); otherwise the waveform pulses with playback.
            if hasTimer {
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black)
                    TimerBadge(state: timerState)
                        .frame(height: notchH - 10)
                        .padding(.leading, 6)
                }
                .frame(width: wingWidth, height: notchH)
                .clipShape(
                    .rect(
                        topLeadingRadius: hasMedia ? 0 : 12,
                        bottomLeadingRadius: hasMedia ? 0 : 12,
                        bottomTrailingRadius: 12,
                        topTrailingRadius: 12,
                        style: .continuous
                    )
                )
            } else if hasMedia, let mvm = vm {
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black)
                    Waveform(phase: phase, playing: mvm.isPlaying)
                        .frame(width: wingWidth - 12, height: notchH - 12)
                        .padding(.leading, 6)
                }
                .frame(width: wingWidth, height: notchH)
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 12,
                        topTrailingRadius: 12,
                        style: .continuous
                    )
                )
            }
        }
        .onReceive(timer) { _ in
            if vm?.isPlaying ?? false { phase += 1 }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = vm?.artworkData, let nsImage = NSImage(data: data) {
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

/// Compact ring + countdown text, fits inside the live-activity right wing.
private struct TimerBadge: View {
    let state: TimerFeature.State

    var body: some View {
        let (remaining, total, playing) = unpack()
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress(remaining: remaining, total: total))
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.97, green: 0.38, blue: 0.38),
                                                Color(red: 1.00, green: 0.66, blue: 0.20)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: remaining)
                Image(systemName: playing ? "timer" : "pause.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 22, height: 22)

            Text(formatRemaining(remaining))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func unpack() -> (TimeInterval, TimeInterval, Bool) {
        switch state {
        case .running(let r, let t): return (r, t, true)
        case .paused(let r, let t):  return (r, t, false)
        case .idle:                  return (0, 0, false)
        }
    }

    private func progress(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - (remaining / total)))
    }

    private func formatRemaining(_ s: TimeInterval) -> String {
        let total = max(0, Int(s.rounded()))
        let m = total / 60
        let r = total % 60
        return String(format: "%d:%02d", m, r)
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

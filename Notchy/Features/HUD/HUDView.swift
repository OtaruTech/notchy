import SwiftUI

/// Small horizontal pill that sits just below the notch hardware while a HUD
/// event is active. Mirrors macOS's centre-screen OSD but anchored on the
/// notch instead of mid-screen.
struct HUDView: View {
    let event: HUDEvent

    private var symbol: String {
        event.muted ? event.kind.mutedSymbol : event.kind.sfSymbol
    }

    private var accent: Color {
        switch event.kind {
        case .volume:            return .white
        case .brightness:        return .yellow
        case .keyboardBacklight: return Color(red: 0.92, green: 0.92, blue: 1.0)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event.muted ? .red.opacity(0.85) : .white.opacity(0.85))
                .frame(width: 18)

            // Filled bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(event.muted
                              ? AnyShapeStyle(.red.opacity(0.55))
                              : AnyShapeStyle(LinearGradient(colors: [accent.opacity(0.9), accent],
                                                             startPoint: .leading, endPoint: .trailing)))
                        .frame(width: geo.size.width * event.level)
                }
            }
            .frame(height: 4)

            Text("\(Int((event.level * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 320)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.92))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }
}

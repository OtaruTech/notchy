import SwiftUI

/// Single-line lyrics pill rendered just below the physical notch when the
/// panel is collapsed. Off by default — user enables via Settings → Now Playing.
struct LyricsTicker: View {
    let synced: [LrcLine]
    let plain: [LrcLine]
    let elapsed: Double
    let duration: Double

    private var usingSynced: Bool { !synced.isEmpty }
    private var displayLines: [LrcLine] { usingSynced ? synced : plain }

    private var activeIndex: Int? {
        let lines = displayLines
        guard !lines.isEmpty else { return nil }
        if usingSynced {
            var idx: Int? = nil
            for (i, line) in lines.enumerated() {
                if line.time <= elapsed { idx = i } else { break }
            }
            return idx
        } else {
            let perLine: Double = duration > 0 ? max(2, duration / Double(lines.count)) : 4
            return max(0, min(lines.count - 1, Int(elapsed / perLine)))
        }
    }

    private var currentText: String {
        let lines = displayLines
        guard let i = activeIndex, i >= 0, i < lines.count else { return "♪" }
        return lines[i].text.isEmpty ? "♪" : lines[i].text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(currentText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .id(activeIndex ?? -1)
                .transition(.opacity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.88))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
        )
        .frame(maxWidth: 380)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.28), value: activeIndex)
    }
}

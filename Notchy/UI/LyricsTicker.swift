import SwiftUI

/// Global single-line lyrics ticker that lives BELOW the physical notch while
/// music plays and the panel is collapsed. Renders a rounded pill with the
/// current LRC line (synced when available, plain otherwise) and crossfades
/// when the active line changes.
///
/// Designed to be pure display — the hover zone does NOT extend over this
/// pill, so passing the cursor through it won't expand the notch.
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
            let secondsPerLine: Double = duration > 0 ? max(2, duration / Double(lines.count)) : 4
            let idx = Int(elapsed / secondsPerLine)
            return max(0, min(lines.count - 1, idx))
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
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.88))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
        )
        .frame(maxWidth: 380)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.28), value: activeIndex)
    }
}

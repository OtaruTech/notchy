import SwiftUI

/// Three-line live lyrics panel.
/// - When `synced` lines are present, advances karaoke-style based on `elapsed`.
/// - Else falls back to `plain` lines and advances them at a constant interval
///   proportional to track `duration` so the panel still feels alive.
struct LyricsView: View {
    let synced: [LrcLine]
    let plain: [LrcLine]
    let elapsed: Double
    let duration: Double

    private var usingSynced: Bool { !synced.isEmpty }
    private var displayLines: [LrcLine] { usingSynced ? synced : plain }
    private var hasSyncedBadge: Bool { !usingSynced && !plain.isEmpty }

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
            // Plain fallback: distribute lines uniformly over the track duration.
            // 4-second floor when duration is unknown.
            let secondsPerLine: Double = duration > 0 ? max(2, duration / Double(lines.count)) : 4
            let idx = Int(elapsed / secondsPerLine)
            return max(0, min(lines.count - 1, idx))
        }
    }

    var body: some View {
        let idx = activeIndex
        let lines = displayLines
        VStack(alignment: .leading, spacing: 2) {
            if hasSyncedBadge {
                Text("Plain lyrics (no timing)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 1)
            }
            line(at: idx.map { $0 - 1 }, in: lines, opacity: 0.35, weight: .regular)
            line(at: idx,                in: lines, opacity: 1.00, weight: .semibold)
            line(at: idx.map { $0 + 1 }, in: lines, opacity: 0.30, weight: .regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: idx)
    }

    @ViewBuilder
    private func line(at index: Int?, in lines: [LrcLine], opacity: Double, weight: Font.Weight) -> some View {
        if let i = index, i >= 0, i < lines.count {
            Text(lines[i].text.isEmpty ? "♪" : lines[i].text)
                .font(.system(size: 12, weight: weight))
                .foregroundStyle(.white.opacity(opacity))
                .lineLimit(1)
                .truncationMode(.tail)
                .id(i)
                .transition(.opacity)
        } else {
            Text(" ")
                .font(.system(size: 12, weight: weight))
                .opacity(0)
        }
    }
}

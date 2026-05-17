import SwiftUI

/// Three-line live lyrics panel — previous (dim), current (bright), next (dim).
/// Lines fade and slide upward when the active line changes.
struct LyricsView: View {
    let lines: [LrcLine]
    let elapsed: Double

    private var activeIndex: Int? {
        guard !lines.isEmpty else { return nil }
        var idx: Int? = nil
        for (i, line) in lines.enumerated() {
            if line.time <= elapsed { idx = i } else { break }
        }
        return idx
    }

    var body: some View {
        let idx = activeIndex
        VStack(alignment: .leading, spacing: 2) {
            line(at: idx.map { $0 - 1 }, opacity: 0.35, weight: .regular)
            line(at: idx,                opacity: 1.00, weight: .semibold)
            line(at: idx.map { $0 + 1 }, opacity: 0.30, weight: .regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: idx)
    }

    @ViewBuilder
    private func line(at index: Int?, opacity: Double, weight: Font.Weight) -> some View {
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

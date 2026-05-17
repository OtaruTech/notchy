import SwiftUI

/// The notch's expanded clipboard view — search field + horizontal card row.
/// Hosted by NotchExpandedView when `state == .clipboard`.
struct ClipboardPanel: View {
    @Bindable var feature: ClipboardFeature
    let onPaste: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if feature.displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(feature.displayed.enumerated()), id: \.element.id) { idx, item in
                                Button {
                                    if UserDefaults.standard.bool(forKey: "notchy.debugLogging") {
                                        NSLog("[Notchy.Clip] card click idx=%d", idx)
                                    }
                                    onPaste(item)
                                } label: {
                                    ItemCard(item: item,
                                             slot: idx < 9 ? idx + 1 : nil,
                                             selected: idx == feature.selectedIndex)
                                }
                                .buttonStyle(.plain)
                                .id(idx)
                                .onHover { hovering in
                                    if hovering { feature.selectedIndex = idx }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .onChange(of: feature.selectedIndex) { _, new in
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
            footerHints
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Keyboard handling (1-9, Enter, Esc, arrows) lives in the app-level
        // NSEvent local monitor in AppDelegate so it works even while the
        // search TextField has focus.
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            TextField("Search clipboard…", text: $feature.query)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .regular))
            Spacer()
            Text("\(feature.count) items")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(feature.query.isEmpty ? "Copy something to get started" : "No matches")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerHints: some View {
        HStack(spacing: 14) {
            hint("↩", "paste")
            hint("1–9", "quick paste")
            hint("← →", "select")
            hint("esc", "close")
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.35))
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.08))
                )
            Text(label)
        }
    }
}


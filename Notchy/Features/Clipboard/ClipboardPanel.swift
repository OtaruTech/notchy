import SwiftUI

/// Paste-style clipboard panel: search bar, kind filter chip row, then a
/// horizontal card strip. Hosted inside NotchExpandedView when
/// `state == .clipboard`.
struct ClipboardPanel: View {
    @Bindable var feature: ClipboardFeature
    let onPaste: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    private static let allKinds: [ClipboardItem.Kind?] =
        [nil, .text, .url, .image, .color, .code, .file, .richtext]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            chipsRow
            cardsRow
            footerHints
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            TextField("Search clipboard…", text: $feature.query)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .regular))
            Spacer()
            Text("\(feature.count) items")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.allKinds.indices, id: \.self) { idx in
                    let kind = Self.allKinds[idx]
                    let count = feature.count(kind: kind)
                    // Hide chips for kinds the user has none of (keeps the bar
                    // tidy — All is always visible).
                    if kind == nil || count > 0 {
                        ClipboardKindChip(
                            kind: kind,
                            count: count,
                            selected: feature.kindFilter == kind,
                            onTap: { feature.kindFilter = kind }
                        )
                    }
                }
            }
        }
        .frame(height: 28)
    }

    private var cardsRow: some View {
        Group {
            if feature.displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(feature.displayed.enumerated()), id: \.element.id) { idx, item in
                                Button { onPaste(item) } label: {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.25))
            Text(emptyStateText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateText: String {
        if !feature.query.isEmpty { return "No matches for \"\(feature.query)\"" }
        if feature.kindFilter != nil { return "No items in this category" }
        return "Copy something to get started"
    }

    private var footerHints: some View {
        HStack(spacing: 12) {
            hint("↩", "paste")
            hint("1–9", "quick paste")
            hint("← →", "select")
            hint("esc", "close")
            Spacer()
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.35))
        .padding(.horizontal, 2)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.08))
                )
            Text(label)
        }
    }
}

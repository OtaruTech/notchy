import SwiftUI
import AppKit

struct DropView: View {
    let items: [DropItem]
    var onClear: () -> Void = {}
    var onAirDrop: () -> Void = {}
    var onEmail: () -> Void = {}
    var onRemove: (UUID) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 16) {
            // LEFT — files
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(items.isEmpty ? "Drop files here" : "\(items.count) file\(items.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    if !items.isEmpty {
                        Text("drag chips out to share")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if items.isEmpty {
                            emptyState
                        } else {
                            ForEach(items) { item in
                                FileChip(item: item, onRemove: { onRemove(item.id) })
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(DesignTokens.glowDrop.opacity(0.5),
                                      style: .init(lineWidth: 1.5, dash: [4, 3]))
                )
            }

            // RIGHT — actions
            VStack(alignment: .leading, spacing: 6) {
                ActionRow(title: "AirDrop", systemImage: "arrow.up.right", action: onAirDrop)
                    .disabled(items.isEmpty)
                ActionRow(title: "Email", systemImage: "envelope", action: onEmail)
                    .disabled(items.isEmpty)
                ActionRow(title: "Clear all", systemImage: "trash", tint: .red, action: onClear)
                    .disabled(items.isEmpty)
            }
            .frame(width: 130)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Drag any file onto the notch")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct FileChip: View {
    let item: DropItem
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .frame(width: 46, height: 56)
                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.85))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            Text(item.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 70)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : .clear)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .help(item.url.path)
    }
}

private struct ActionRow: View {
    let title: String
    let systemImage: String
    var tint: Color = DesignTokens.glowDrop
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(isEnabled ? 0.35 : 0.15),
                                in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(isEnabled ? 0.08 : 0.03),
                        in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.35))
        }
        .buttonStyle(.plain)
    }
}

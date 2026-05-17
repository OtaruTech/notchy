import SwiftUI

struct DropView: View {
    let items: [DropItem]
    var onClear: () -> Void = {}
    var onAirDrop: () -> Void = {}
    var onEmail: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if items.isEmpty {
                        Text("Drop files here")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(items) { item in
                            FileChip(item: item)
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(DesignTokens.glowDrop.opacity(0.5),
                                  style: .init(lineWidth: 1.5, dash: [4, 3]))
            )

            VStack(alignment: .leading, spacing: 6) {
                ActionRow(title: "AirDrop",  systemImage: "arrow.up.right", action: onAirDrop)
                ActionRow(title: "Email",    systemImage: "envelope",       action: onEmail)
                ActionRow(title: "Clear all",systemImage: "trash",          action: onClear)
            }
            .frame(width: 116)
        }
    }
}

private struct FileChip: View {
    let item: DropItem
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [.gray, .black.opacity(0.7)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 56)
                .overlay(
                    Text(item.url.pathExtension.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6),
                    alignment: .bottom
                )
            Text(item.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 62)
        }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
    }
}

private struct ActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 20, height: 20)
                    .background(DesignTokens.glowDrop.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                Text(title).font(.system(size: 11))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

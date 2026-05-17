import SwiftUI
import AppKit

/// One clipboard history card. Kind-aware preview.
struct ItemCard: View {
    let item: ClipboardItem
    /// 1-9 quick-paste slot, or nil if beyond the first 9.
    let slot: Int?
    var selected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewArea
            footer
        }
        .frame(width: 110, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? .white.opacity(0.9) : .white.opacity(0.10),
                                lineWidth: selected ? 1.5 : 0.5)
                )
        )
        .overlay(alignment: .topTrailing) {
            if let slot {
                Text("\(slot)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var previewArea: some View {
        switch item.kind {
        case .color:
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(colorFromString(item.preview) ?? Color.gray)
                Text(item.preview)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(6)
            }
            .frame(maxHeight: .infinity)
        case .image:
            if let path = item.payloadPath, let img = NSImage(contentsOf: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                fallbackKindGlyph
            }
        case .file:
            VStack(spacing: 4) {
                if let path = item.payloadPath {
                    let icon = NSWorkspace.shared.icon(forFile: path.path)
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "doc").font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(item.preview)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .url:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.85))
                if let host = URL(string: item.payloadText ?? "")?.host {
                    Text(host)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(item.preview)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .code:
            Text(item.preview)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.green.opacity(0.85))
                .lineLimit(8)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .richtext, .text:
            Text(item.preview)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(6)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Image(systemName: item.kind.sfSymbol)
                .font(.system(size: 9, weight: .semibold))
            Text(relativeAge)
            Spacer(minLength: 0)
            if let name = item.sourceName {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(.white.opacity(0.45))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.25))
    }

    private var fallbackKindGlyph: some View {
        Image(systemName: item.kind.sfSymbol)
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var relativeAge: String {
        let delta = Int(-item.updatedAt.timeIntervalSinceNow)
        if delta < 60 { return "\(delta)s ago" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86_400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86_400)d ago"
    }

    private func colorFromString(_ s: String) -> Color? {
        var str = s
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 3 || str.count == 6 || str.count == 8 else { return nil }
        let scanner = Scanner(string: str)
        var hex: UInt64 = 0
        guard scanner.scanHexInt64(&hex) else { return nil }
        let r, g, b, a: Double
        switch str.count {
        case 3:
            r = Double((hex >> 8) & 0xF) / 15.0
            g = Double((hex >> 4) & 0xF) / 15.0
            b = Double(hex & 0xF) / 15.0
            a = 1
        case 6:
            r = Double((hex >> 16) & 0xFF) / 255.0
            g = Double((hex >> 8) & 0xFF) / 255.0
            b = Double(hex & 0xFF) / 255.0
            a = 1
        default:
            r = Double((hex >> 24) & 0xFF) / 255.0
            g = Double((hex >> 16) & 0xFF) / 255.0
            b = Double((hex >> 8) & 0xFF) / 255.0
            a = Double(hex & 0xFF) / 255.0
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

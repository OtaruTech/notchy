import SwiftUI
import AppKit

/// A single clipboard history card. Glassy, kind-aware preview with a
/// coloured accent stripe on top and a metadata footer.
struct ItemCard: View {
    let item: ClipboardItem
    /// 1-9 quick-paste slot, or nil if beyond the first 9.
    let slot: Int?
    var selected: Bool = false

    private static let size = CGSize(width: 152, height: 180)

    var body: some View {
        VStack(spacing: 0) {
            accentStripe
            previewArea
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            selected ? accent.opacity(0.95) : .white.opacity(0.10),
                            lineWidth: selected ? 1.5 : 0.5
                        )
                )
                .shadow(color: selected ? accent.opacity(0.25) : .black.opacity(0.25),
                        radius: selected ? 14 : 8, y: selected ? 6 : 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let slot {
                Text("\(slot)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(.black.opacity(0.55))
                    )
                    .padding(8)
            }
        }
        .scaleEffect(selected ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.18), value: selected)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Coloured strip at the very top so the kind is recognisable at a glance.
    private var accentStripe: some View {
        Rectangle()
            .fill(accent)
            .frame(height: 3)
    }

    @ViewBuilder
    private var previewArea: some View {
        switch item.kind {
        case .color:
            colorPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        case .url:
            urlPreview
        case .code:
            codePreview
        case .richtext, .text:
            textPreview
        }
    }

    private var colorPreview: some View {
        ZStack {
            (colorFromString(item.preview) ?? Color.gray)
            VStack(spacing: 2) {
                Spacer()
                Text(item.preview)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Spacer().frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var imagePreview: some View {
        Group {
            if let path = item.payloadPath, let img = NSImage(contentsOf: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var filePreview: some View {
        VStack(spacing: 6) {
            if let path = item.payloadPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(item.preview)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                if let host = URL(string: item.payloadText ?? "")?.host {
                    Text(host)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            Text(pathFor(item.payloadText ?? ""))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var codePreview: some View {
        Text(item.preview)
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Color(red: 0.6, green: 0.95, blue: 0.7))
            .lineLimit(10)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var textPreview: some View {
        Text(item.preview)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(8)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: item.kind.sfSymbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
            Text(relativeAge)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let name = item.sourceName {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 72, alignment: .trailing)
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.30))
    }

    // MARK: helpers

    private var accent: Color {
        switch item.kind {
        case .text:     return Color(red: 0.55, green: 0.62, blue: 0.85)
        case .richtext: return Color(red: 0.95, green: 0.55, blue: 0.85)
        case .url:      return Color(red: 0.30, green: 0.62, blue: 1.00)
        case .image:    return Color(red: 1.00, green: 0.60, blue: 0.30)
        case .file:     return Color(red: 0.60, green: 0.80, blue: 0.50)
        case .color:    return Color(red: 0.97, green: 0.38, blue: 0.55)
        case .code:     return Color(red: 0.45, green: 0.85, blue: 0.55)
        }
    }

    private var relativeAge: String {
        let delta = Int(-item.updatedAt.timeIntervalSinceNow)
        if delta < 60 { return "just now" }
        if delta < 3600 { return "\(delta / 60)m" }
        if delta < 86_400 { return "\(delta / 3600)h" }
        return "\(delta / 86_400)d"
    }

    private func pathFor(_ urlString: String) -> String {
        if let url = URL(string: urlString), !url.path.isEmpty, url.path != "/" {
            return url.path + (url.query.map { "?\($0)" } ?? "")
        }
        return urlString
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

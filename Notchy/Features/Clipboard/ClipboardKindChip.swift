import SwiftUI

/// Filter chip used in ClipboardPanel's filter row. Selected chip is filled
/// with the kind's accent colour; idle chips are subtle outlined pills.
struct ClipboardKindChip: View {
    let kind: ClipboardItem.Kind?   // nil = "All"
    let count: Int
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(selected ? .white.opacity(0.2) : .white.opacity(0.10))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(selected ? accent.opacity(0.85) : .white.opacity(0.06))
                    .overlay(
                        Capsule().stroke(selected ? .clear : .white.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(selected ? .white : .white.opacity(0.75))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: selected)
    }

    private var label: String {
        guard let kind else { return "All" }
        switch kind {
        case .text:     return "Text"
        case .richtext: return "Rich"
        case .url:      return "Links"
        case .image:    return "Images"
        case .file:     return "Files"
        case .color:    return "Colors"
        case .code:     return "Code"
        }
    }

    private var icon: String {
        kind?.sfSymbol ?? "tray.full"
    }

    private var accent: Color {
        guard let kind else { return Color(red: 0.78, green: 0.55, blue: 1.00) }
        switch kind {
        case .text:     return Color(red: 0.55, green: 0.62, blue: 0.85)
        case .richtext: return Color(red: 0.95, green: 0.55, blue: 0.85)
        case .url:      return Color(red: 0.30, green: 0.62, blue: 1.00)
        case .image:    return Color(red: 1.00, green: 0.60, blue: 0.30)
        case .file:     return Color(red: 0.60, green: 0.80, blue: 0.50)
        case .color:    return Color(red: 0.97, green: 0.38, blue: 0.55)
        case .code:     return Color(red: 0.45, green: 0.85, blue: 0.55)
        }
    }
}

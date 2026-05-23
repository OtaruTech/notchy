import SwiftUI

/// The notification pill that drops down from the notch when an external
/// notification arrives. Click anywhere on the pill to dismiss (and, if the
/// notification has a `cwd`, focus the terminal).
struct NotificationPillView: View {
    let note: ExternalNotification
    var onClick: () -> Void = {}

    var body: some View {
        Button(action: onClick) {
            HStack(alignment: .top, spacing: 10) {
                iconBadge
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(note.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(sourceLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .stroke(.white.opacity(0.18), lineWidth: 0.5)
                            )
                    }
                    if !note.body.isEmpty {
                        Text(note.body)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if note.sticky {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 380, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
        .help(note.cwd.map { "Click to focus terminal — \($0)" } ?? "Click to dismiss")
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 26, height: 26)
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.black.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    private var accent: Color {
        switch note.kind {
        case .info:         return .blue
        case .inputNeeded:  return .orange
        case .toolApproval: return .yellow
        case .complete:     return .green
        case .error:        return .red
        }
    }

    private var iconName: String {
        switch note.kind {
        case .info:         return "bell.fill"
        case .inputNeeded:  return "hand.raised.fill"
        case .toolApproval: return "checkmark.shield.fill"
        case .complete:     return "checkmark.circle.fill"
        case .error:        return "exclamationmark.triangle.fill"
        }
    }

    private var sourceLabel: String {
        switch note.source {
        case "claude-code":         return "CLAUDE"
        case "claude-code-mascot":  return "MASCOT"
        default:                    return note.source.uppercased()
        }
    }
}

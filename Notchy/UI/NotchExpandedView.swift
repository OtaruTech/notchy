import SwiftUI

struct NotchExpandedView: View {
    let state: NotchState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                .fill(.black)
                .shadow(
                    color: glowColor.opacity(state.isExpanded ? DesignTokens.glowOpacity : 0),
                    radius: 40, x: 0, y: 12
                )
                .overlay {
                    content
                        .padding(.top, DesignTokens.notchHeight + 6)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                        .opacity(state.isExpanded ? 1 : 0)
                }
        }
        .frame(width: width, height: height)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: DesignTokens.cornerRadius,
                bottomTrailingRadius: DesignTokens.cornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    private var width: CGFloat {
        state.isExpanded ? DesignTokens.expandedWidth :
        (state == .hint ? DesignTokens.notchWidth + 8 : DesignTokens.notchWidth)
    }

    private var height: CGFloat {
        switch state {
        case .idle, .hint: return DesignTokens.notchHeight + (state == .hint ? 3 : 0)
        case .drop: return DesignTokens.expandedHeightDrop
        default: return DesignTokens.expandedHeightDefault
        }
    }

    private var glowColor: Color {
        switch state {
        case .media: return DesignTokens.glowMedia
        case .drop: return DesignTokens.glowDrop
        case .airpods: return DesignTokens.glowAirPods
        case .hint, .idle: return .clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .media: Text("Media (Phase 3)").foregroundStyle(.white)
        case .drop:  Text("Drop (Phase 4)").foregroundStyle(.white)
        case .airpods: Text("AirPods (Phase 5)").foregroundStyle(.white)
        default: EmptyView()
        }
    }
}

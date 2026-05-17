import SwiftUI

struct NotchExpandedView: View {
    let state: NotchState
    let mediaVM: NowPlayingVM?
    let mediaFeature: MediaFeature
    let dropFeature: DropFeature
    let onAirDrop: () -> Void
    let onEmail: () -> Void
    let btFeature: BTFeature

    @AppStorage("notchy.hintEnabled") private var hintEnabled = true

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

            if state == .hint, hintEnabled {
                NotchHint().transition(.opacity)
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
        case .hint, .idle, .calendar, .timer: return .clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .media:
            if let vm = mediaVM {
                MediaView(
                    vm: vm,
                    onPlayPause: { mediaFeature.playPause() },
                    onPrev: { mediaFeature.prev() },
                    onNext: { mediaFeature.next() }
                )
            } else {
                Text("No media").foregroundStyle(.white.opacity(0.7))
            }
        case .drop:
            DropView(
                items: dropFeature.items,
                onClear: { dropFeature.clearAll() },
                onAirDrop: onAirDrop,
                onEmail: onEmail
            )
        case .airpods:
            if let vm = btFeature.connected {
                AirPodsView(vm: vm)
            } else {
                Text("AirPods").foregroundStyle(.white.opacity(0.7))
            }
        default: EmptyView()
        }
    }
}

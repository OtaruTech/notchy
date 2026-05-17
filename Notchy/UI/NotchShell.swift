import SwiftUI

struct NotchShell: View {
    let stateMachine: NotchStateMachine
    let mediaFeature: MediaFeature
    let dropFeature: DropFeature
    let onAirDrop: () -> Void
    let onEmail: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NotchExpandedView(
                state: stateMachine.state,
                mediaVM: mediaFeature.current,
                mediaFeature: mediaFeature,
                dropFeature: dropFeature,
                onAirDrop: onAirDrop,
                onEmail: onEmail
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DesignTokens.springExpand, value: stateMachine.state)
    }
}

import SwiftUI

struct NotchShell: View {
    let stateMachine: NotchStateMachine
    let mediaFeature: MediaFeature

    var body: some View {
        VStack(spacing: 0) {
            NotchExpandedView(state: stateMachine.state, mediaVM: mediaFeature.current)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DesignTokens.springExpand, value: stateMachine.state)
    }
}

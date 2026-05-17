import SwiftUI

struct NotchHint: View {
    var body: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(LinearGradient(colors: [.pink, .purple],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: DesignTokens.notchWidth - 24, height: 3)
        }
        .frame(width: DesignTokens.notchWidth, height: 3)
        .padding(.top, DesignTokens.notchHeight)
    }
}

import SwiftUI

enum DesignTokens {
    // Sizing
    static let notchWidth: CGFloat = 210
    static let notchHeight: CGFloat = 32
    static let expandedWidth: CGFloat = 540
    static let expandedHeightDefault: CGFloat = 180
    static let expandedHeightDrop: CGFloat = 220
    static let cornerRadius: CGFloat = 28

    // Animation
    static let springExpand: Animation = .spring(response: 0.42, dampingFraction: 0.78)
    static let hoverDelay: Duration = .milliseconds(120)
    static let hoverDismissDelay: Duration = .milliseconds(250)
    static let dragDismissDelay: Duration = .seconds(5)
    static let airPodsDismissDelay: Duration = .seconds(3)

    // Color glow per feature
    static let glowMedia: Color = .init(red: 0.71, green: 0.55, blue: 1.00)
    static let glowDrop: Color = .init(red: 0.22, green: 0.74, blue: 0.97)
    static let glowAirPods: Color = .init(red: 0.29, green: 0.87, blue: 0.50)
    static let glowOpacity: Double = 0.35
}

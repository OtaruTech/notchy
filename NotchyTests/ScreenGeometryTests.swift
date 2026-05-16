import Testing
import AppKit
@testable import Notchy

@MainActor
struct ScreenGeometryTests {

    @Test func notchRectIsNilWhenNoSafeAreaInsets() {
        let result = ScreenGeometry.notchRect(safeAreaTop: 0, screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect(result == nil)
    }

    @Test func notchRectCentersBelowTopWithKnownWidth() {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let r = ScreenGeometry.notchRect(safeAreaTop: 38, screenFrame: frame)
        let notch = try? #require(r)
        #expect(notch?.width == 210)
        #expect(notch?.height == 38)
        #expect(notch?.midX == 756)
    }

    @Test func hotZoneExtends4ptBelowNotch() {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let hot = ScreenGeometry.hotZone(safeAreaTop: 38, screenFrame: frame)!
        #expect(hot.height == 42)
    }
}

import Testing
import SwiftUI
import AppKit
import SnapshotTesting
@testable import Notchy

@MainActor
struct DropViewSnapshots {

    private func host<V: View>(_ view: V, width: CGFloat = 540, height: CGFloat = 220) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    @Test func empty() {
        let view = DropView(items: [])
            .frame(width: 540, height: 220)
            .background(Color.black)
        assertSnapshot(of: host(view), as: .image, named: "empty")
    }

    @Test func threeFiles() {
        let items = [
            DropItem(url: URL(fileURLWithPath: "/tmp/report.pdf")),
            DropItem(url: URL(fileURLWithPath: "/tmp/screen.jpg")),
            DropItem(url: URL(fileURLWithPath: "/tmp/notes.md"))
        ]
        let view = DropView(items: items)
            .frame(width: 540, height: 220)
            .background(Color.black)
        assertSnapshot(of: host(view), as: .image, named: "three-files")
    }
}

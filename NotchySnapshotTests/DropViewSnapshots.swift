import Testing
import SwiftUI
import AppKit
import SnapshotTesting
@testable import Notchy

@MainActor
struct DropViewSnapshots {

    @Test func empty() {
        let view = DropView(items: [])
            .frame(width: 540, height: 220)
            .background(Color.black)
        assertSnapshot(of: snapshotHost(view, width: 540, height: 220), as: .image, named: "empty")
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
        assertSnapshot(of: snapshotHost(view, width: 540, height: 220), as: .image, named: "three-files")
    }
}

import AppKit

@MainActor
final class DragSession: NSObject, NSDraggingDestination {

    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onDrop: ([URL]) -> Void = { _ in }

    func attach(to view: NSView) {
        view.registerForDraggedTypes([.fileURL])
        let intermediary = DragInterceptView(frame: view.bounds, session: self)
        intermediary.autoresizingMask = [.width, .height]
        view.addSubview(intermediary)
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onEnter()
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        onExit()
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        onDrop(urls)
        return true
    }
}

private final class DragInterceptView: NSView {
    weak var session: DragSession?
    init(frame: NSRect, session: DragSession) {
        self.session = session
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        session?.draggingEntered(sender) ?? []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        session?.draggingExited(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        session?.performDragOperation(sender) ?? false
    }
}

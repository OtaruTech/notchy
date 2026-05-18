import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A single-row hotkey recorder. Click → captures the next key chord → stores
/// the binding via `HotKeyCenter.setBinding` and invokes `onChange` so the
/// owning view can call `HotKeyCenter.reloadBindings()`.
struct HotKeyRecorderView: View {
    let action: HotKeyCenter.Action
    var onChange: () -> Void = {}

    @State private var recording = false
    @State private var binding: HotKeyBinding
    @State private var error: String?

    init(action: HotKeyCenter.Action, onChange: @escaping () -> Void = {}) {
        self.action = action
        self.onChange = onChange
        self._binding = State(initialValue: HotKeyCenter.binding(for: action))
    }

    var body: some View {
        HStack {
            Text(action.displayName)
            Spacer()
            Button {
                recording.toggle()
            } label: {
                Text(recording ? "Press a key…" : binding.displayString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(minWidth: 80)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(recording ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: recording ? 2 : 1)
                    )
            }
            .buttonStyle(.plain)
            .background(
                KeyCaptureRepresentable(isRecording: $recording) { keyCode, modifiers in
                    handleCapture(keyCode: keyCode, modifiers: modifiers)
                }
            )
            Button {
                HotKeyCenter.setBinding(nil, for: action)
                binding = action.defaultBinding
                onChange()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.borderless)
            .help("Reset to default")
        }
        if let error {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    private func handleCapture(keyCode: UInt32, modifiers: UInt32) {
        guard let validated = Self.validate(keyCode: keyCode, modifiers: modifiers) else {
            error = "That combo is reserved by the system or has no modifiers."
            recording = false
            return
        }
        binding = validated
        HotKeyCenter.setBinding(validated, for: action)
        error = nil
        recording = false
        onChange()
    }

    /// Reject empty modifiers + system reservations (⌘Q, ⌘Tab, ⌘W, ⌘Space).
    private static func validate(keyCode: UInt32, modifiers: UInt32) -> HotKeyBinding? {
        guard modifiers != 0 else { return nil }
        let cmdOnly = (modifiers & ~UInt32(cmdKey)) == 0
        if cmdOnly {
            switch Int(keyCode) {
            case kVK_ANSI_Q, kVK_Tab, kVK_ANSI_W, kVK_Space:
                return nil
            default: break
            }
        }
        return HotKeyBinding(keyCode: keyCode, modifiers: modifiers)
    }
}

// MARK: NSViewRepresentable wrapper

/// Hosts an invisible NSView while `isRecording == true` that captures the
/// next key event and reports `(keyCode, modifiers)` in Carbon flags.
private struct KeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        KeyCaptureView()
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.isRecording = isRecording
        if isRecording { DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) } }
    }
}

private final class KeyCaptureView: NSView {
    var onCapture: ((UInt32, UInt32) -> Void)?
    var isRecording = false

    override var acceptsFirstResponder: Bool { isRecording }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let carbonMods = Self.carbonModifiers(from: event.modifierFlags)
        onCapture?(UInt32(event.keyCode), carbonMods)
    }

    override func flagsChanged(with event: NSEvent) {
        // Don't treat pure modifier presses as commits — wait for a key.
        super.flagsChanged(with: event)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var out: UInt32 = 0
        if flags.contains(.command) { out |= UInt32(cmdKey) }
        if flags.contains(.option)  { out |= UInt32(optionKey) }
        if flags.contains(.control) { out |= UInt32(controlKey) }
        if flags.contains(.shift)   { out |= UInt32(shiftKey) }
        return out
    }
}

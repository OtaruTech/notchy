import Foundation
import CoreAudio
import AudioToolbox

fileprivate let kDefaultOutputSelector = kAudioHardwarePropertyDefaultOutputDevice
/// Per-element volume scalar on the master element. Reliably notifies on
/// every system volume change (F11/F12, AppleScript, etc.).
fileprivate let kVolumeSelector: AudioObjectPropertySelector = kAudioDevicePropertyVolumeScalar
fileprivate let kMuteSelector = kAudioDevicePropertyMute

fileprivate func _hudLog(_ msg: String) {
    guard UserDefaults.standard.bool(forKey: "notchy.debugLogging") else { return }
    let line = "\(Date()) [Notchy.HUD] \(msg)\n"
    if let data = line.data(using: .utf8) {
        let path = "/tmp/notchy.log"
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile(); try? h.write(contentsOf: data); try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Watches the default audio output device's volume + mute state via
/// CoreAudio. On change, calls `onChange` with a normalised level + mute flag.
@MainActor
final class VolumeMonitor {

    var onChange: (Double, Bool) -> Void = { _, _ in }

    private var currentDeviceID: AudioDeviceID = 0
    private var volumeBlock: AudioObjectPropertyListenerBlock?
    private var muteBlock: AudioObjectPropertyListenerBlock?

    func start() {
        _hudLog("VolumeMonitor.start()")
        attachToDefaultDevice()
        // Re-attach when the default output device changes (AirPods connect, etc.).
        var addr = address(kDefaultOutputSelector, scope: kAudioObjectPropertyScopeGlobal)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                _hudLog("default output device changed → re-attach")
                self?.attachToDefaultDevice()
            }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block
        )
    }

    // MARK: device wiring

    private func attachToDefaultDevice() {
        let id = readDefaultDevice()
        guard id != 0 else { return }
        if currentDeviceID != 0, currentDeviceID != id {
            removeListeners(from: currentDeviceID)
        }
        currentDeviceID = id

        // Listen on master element + both channels — different devices use
        // different elements as the "volume changed" source of truth.
        let vBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.fireCurrent() }
        }
        volumeBlock = vBlock
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kVolumeSelector,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            AudioObjectAddPropertyListenerBlock(id, &addr, DispatchQueue.main, vBlock)
        }

        var muteAddr = address(kMuteSelector, scope: kAudioDevicePropertyScopeOutput)
        let mBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.fireCurrent() }
        }
        muteBlock = mBlock
        AudioObjectAddPropertyListenerBlock(id, &muteAddr, DispatchQueue.main, mBlock)
        _hudLog("attached to device \(id)")
    }

    private func removeListeners(from device: AudioDeviceID) {
        if let v = volumeBlock {
            var addr = address(kVolumeSelector, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(device, &addr, DispatchQueue.main, v)
        }
        if let m = muteBlock {
            var addr = address(kMuteSelector, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(device, &addr, DispatchQueue.main, m)
        }
        volumeBlock = nil
        muteBlock = nil
    }

    private func fireCurrent() {
        guard currentDeviceID != 0 else { return }
        let level = readVolume(device: currentDeviceID)
        let muted = readMute(device: currentDeviceID)
        _hudLog("volume change device=\(currentDeviceID) level=\(level) muted=\(muted)")
        onChange(level, muted)
    }

    // MARK: readers

    private func readDefaultDevice() -> AudioDeviceID {
        var addr = address(kDefaultOutputSelector, scope: kAudioObjectPropertyScopeGlobal)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var id: AudioDeviceID = 0
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id
        )
        return id
    }

    private func readVolume(device: AudioDeviceID) -> Double {
        // Try element 0 (master) first.
        if let level = readVolumeElement(device: device, element: kAudioObjectPropertyElementMain) {
            if level > 0 { return level }
        }
        // Average per-channel volumes — many devices (esp. BT) expose
        // per-channel scalars only.
        var values: [Double] = []
        for channel: AudioObjectPropertyElement in 1...2 {
            if let v = readVolumeElement(device: device, element: channel) {
                values.append(v)
            }
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func readVolumeElement(device: AudioDeviceID, element: AudioObjectPropertyElement) -> Double? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kVolumeSelector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var size = UInt32(MemoryLayout<Float32>.size)
        var value: Float32 = 0
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    private func readMute(device: AudioDeviceID) -> Bool {
        var addr = address(kMuteSelector, scope: kAudioDevicePropertyScopeOutput)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    private func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

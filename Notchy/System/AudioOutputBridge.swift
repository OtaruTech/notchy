import Foundation
import CoreAudio
import Observation

/// The system audio output the user is currently hearing audio through.
struct AudioOutput: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case builtIn      // MacBook speakers
        case headphones   // wired 3.5mm jack
        case airpods      // Bluetooth, name contains "AirPods" or "Beats"
        case bluetooth    // generic BT (other speakers/headsets)
        case usb          // USB DAC / interface
        case hdmi
        case displayPort
        case airplay
        case other

        var sfSymbol: String {
            switch self {
            case .builtIn:     return "laptopcomputer"
            case .headphones:  return "headphones"
            case .airpods:     return "airpods"
            case .bluetooth:   return "headphones"
            case .usb:         return "cable.connector"
            case .hdmi, .displayPort: return "tv"
            case .airplay:     return "airplayaudio"
            case .other:       return "speaker.wave.2.fill"
            }
        }
    }

    var name: String
    var kind: Kind
}

/// Tracks the macOS default audio output device and emits changes via Observation.
/// Uses CoreAudio's HAL — no entitlement required.
@MainActor
@Observable
final class AudioOutputBridge {

    private(set) var current: AudioOutput?

    private var listenerInstalled = false

    init() {}

    func start() {
        refresh()
        installListener()
    }

    func refresh() {
        current = Self.readDefaultOutput()
    }

    private func installListener() {
        guard !listenerInstalled else { return }
        listenerInstalled = true
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
        )
    }

    /// Reads the current default output device via CoreAudio HAL.
    private static func readDefaultOutput() -> AudioOutput? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }

        let name = stringProperty(deviceID, kAudioObjectPropertyName) ?? "Output"
        let transport = u32Property(deviceID, kAudioDevicePropertyTransportType) ?? 0
        let kind = classify(name: name, transport: transport)
        return AudioOutput(name: friendlyName(name, kind: kind), kind: kind)
    }

    private static func classify(name: String, transport: UInt32) -> AudioOutput.Kind {
        let n = name.lowercased()
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if n.contains("airpods") || n.contains("beats") { return .airpods }
            return .bluetooth
        case kAudioDeviceTransportTypeBuiltIn:
            if n.contains("headphone") || n.contains("耳机") { return .headphones }
            return .builtIn
        case kAudioDeviceTransportTypeUSB:        return .usb
        case kAudioDeviceTransportTypeHDMI:       return .hdmi
        case kAudioDeviceTransportTypeDisplayPort: return .displayPort
        case kAudioDeviceTransportTypeAirPlay:    return .airplay
        default:
            if n.contains("airpods") || n.contains("beats") { return .airpods }
            if n.contains("headphone") || n.contains("耳机") { return .headphones }
            return .other
        }
    }

    /// MacBook built-in speakers usually report a generic "MacBook Pro Speakers" / "扬声器".
    /// Shorten for the badge.
    private static func friendlyName(_ raw: String, kind: AudioOutput.Kind) -> String {
        switch kind {
        case .builtIn:
            return "MacBook Speakers"
        case .headphones:
            return "Headphones"
        default:
            return raw
        }
    }

    private static func stringProperty(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr,
              size == UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        else { return nil }
        var cfRef: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &cfRef) { ptr in
            AudioObjectGetPropertyData(device, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr, let cf = cfRef?.takeRetainedValue() else { return nil }
        return cf as String
    }

    private static func u32Property(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }
}

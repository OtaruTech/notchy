import AppKit
import AVFoundation
import CoreAudio

/// Detects whether ANY app is currently using the microphone or front
/// camera. Phase-A implementation reports a simple boolean per device;
/// Phase B (post-v0.4) walks the audit token to attribute the consumer
/// to an app bundle.
///
/// macOS provides two complementary signals:
/// 1. CoreAudio: `kAudioDevicePropertyDeviceIsRunningSomewhere` on the
///    default input device — fires whenever any process opens the mic.
/// 2. AVCaptureDevice notifications + `isInUseByAnotherApplication` poll
///    for camera. (CoreMediaIO has a similar property but it's private.)
@MainActor
final class PrivacyMonitor {

    private let status: SystemStatusFeature
    private var pollTimer: Timer?
    private var audioListener: AudioObjectPropertyListenerBlock?
    private var listenerDevice: AudioDeviceID = 0

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        attachMicListener()
        // Camera doesn't have a public listener — poll every 2s.
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCamera() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
        refreshMic()
        refreshCamera()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if listenerDevice != 0, let block = audioListener {
            var addr = micRunningAddress
            AudioObjectRemovePropertyListenerBlock(listenerDevice, &addr, DispatchQueue.main, block)
        }
        audioListener = nil
    }

    // MARK: mic

    private var micRunningAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func attachMicListener() {
        guard let deviceID = defaultInputDevice() else { return }
        listenerDevice = deviceID
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refreshMic() }
        }
        audioListener = block
        var addr = micRunningAddress
        AudioObjectAddPropertyListenerBlock(deviceID, &addr, DispatchQueue.main, block)
    }

    private func refreshMic() {
        guard listenerDevice != 0 else {
            status.micInUse = nil
            return
        }
        var addr = micRunningAddress
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        AudioObjectGetPropertyData(listenerDevice, &addr, 0, nil, &size, &value)
        status.micInUse = value != 0 ? SystemStatusFeature.PrivacyConsumer(appName: nil) : nil
    }

    private func defaultInputDevice() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var id: AudioDeviceID = 0
        let r = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id
        )
        guard r == noErr, id != 0 else { return nil }
        return id
    }

    // MARK: camera

    private func refreshCamera() {
        // AVCaptureDevice.isInUseByAnotherApplication only tells us if the
        // device is used by *another* app. We probe the front camera if
        // available; falls back to any default video device.
        let device = AVCaptureDevice.default(for: .video)
            ?? AVCaptureDevice.devices(for: .video).first
        guard let device else {
            status.camInUse = nil
            return
        }
        let inUse = device.isInUseByAnotherApplication
        status.camInUse = inUse ? SystemStatusFeature.PrivacyConsumer(appName: nil) : nil
    }
}

import SwiftUI

/// Default hover-expanded content: clock + date + system stats + next event.
/// Shown when the user hovers the notch and no media is playing.
struct DashboardView: View {
    let nextEvent: EventVM?
    let snapshot: SystemSnapshot
    var status: SystemStatusFeature? = nil
    @AppStorage("notchy.gaugeEnabled") private var gaugeEnabled = true
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            mainRow
            extrasSection
        }
    }

    private var mainRow: some View {
        HStack(spacing: 18) {
            // ── Time + date column ──────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                    privacyDots
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(dateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Divider()
                .frame(width: 1, height: 60)
                .overlay(.white.opacity(0.12))

            // ── Next event / hint column ────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.0)
                    if let ev = nextEvent, ev.isInProgress {
                        liveBadge
                    }
                }
                if let ev = nextEvent {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(Color(cgColor: ev.calendarColor))
                            .frame(width: 3, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ev.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(ev.startTime) – \(ev.endTime)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                } else {
                    Text("Nothing scheduled")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Drop files · Play music · Connect AirPods")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── System stats column (gated by Settings toggle) ──
            if gaugeEnabled {
                VStack(alignment: .trailing, spacing: 8) {
                    statRow(
                        icon: "cpu.fill",
                        iconColor: cpuColor,
                        label: "CPU",
                        value: "\(snapshot.cpuPercent)%"
                    )
                    if let bat = snapshot.batteryPercent {
                        statRow(
                            icon: snapshot.isCharging ? "bolt.fill" : "battery.\(batteryBucket(bat))",
                            iconColor: snapshot.isCharging ? .green : (bat < 20 ? .red : .white.opacity(0.7)),
                            label: snapshot.isCharging ? "POWER" : "BATT",
                            value: "\(bat)%"
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: gaugeEnabled)
        .onReceive(timer) { now = $0 }
    }

    /// Two coloured dots next to the clock — mic (orange) + camera (green) —
    /// gated by Settings and only visible when the device is in use.
    @ViewBuilder
    private var privacyDots: some View {
        let enabled = UserDefaults.standard.object(forKey: "notchy.indicatorPrivacyEnabled") as? Bool ?? true
        if enabled, let status {
            VStack(spacing: 4) {
                if status.micInUse != nil {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                        .help("Microphone in use")
                }
                if status.camInUse != nil {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                        .help("Camera in use")
                }
            }
        }
    }

    /// Extras section — system status rows added in v0.4 Phase 4–8.
    /// Each row gates on its own UserDefault + on whether the data source
    /// has anything to show. Hidden entirely when none apply.
    @ViewBuilder
    var extrasSection: some View {
        if let status {
            VStack(spacing: 4) {
                chargingRow(status: status)
                networkRow(status: status)
                btDevicesRow(status: status)
                caffeineRow(status: status)
            }
        }
    }

    @ViewBuilder
    private func networkRow(status: SystemStatusFeature) -> some View {
        let enabled = UserDefaults.standard.object(forKey: "notchy.indicatorNetworkEnabled") as? Bool ?? true
        let hideIdle = UserDefaults.standard.object(forKey: "notchy.indicatorNetworkHideIdle") as? Bool ?? true
        let idleThresholdBps = 50_000.0  // 50 KB/s
        let isBusy = status.networkDown > idleThresholdBps || status.networkUp > idleThresholdBps
        if enabled, (!hideIdle || isBusy) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(formatRate(status.networkDown))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.purple)
                    Text(formatRate(status.networkUp))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func formatRate(_ bps: Double) -> String {
        switch bps {
        case ..<1024:           return "\(Int(bps)) B/s"
        case 1024..<1_048_576:  return String(format: "%.1f KB/s", bps / 1024)
        default:                return String(format: "%.1f MB/s", bps / 1_048_576)
        }
    }

    @ViewBuilder
    private func btDevicesRow(status: SystemStatusFeature) -> some View {
        let enabled = UserDefaults.standard.object(forKey: "notchy.indicatorBTDevicesEnabled") as? Bool ?? true
        if enabled, !status.btDevices.isEmpty {
            HStack(spacing: 10) {
                ForEach(status.btDevices) { device in
                    HStack(spacing: 4) {
                        Image(systemName: btIcon(device.kind))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(formatBattery(device))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func btIcon(_ kind: SystemStatusFeature.BTDeviceBattery.Kind) -> String {
        switch kind {
        case .mouse:      return "computermouse.fill"
        case .keyboard:   return "keyboard.fill"
        case .watch:      return "applewatch"
        case .airpods:    return "airpods"
        case .headphones: return "headphones"
        case .generic:    return "antenna.radiowaves.left.and.right"
        }
    }

    private func formatBattery(_ d: SystemStatusFeature.BTDeviceBattery) -> String {
        if d.kind == .airpods {
            let parts = [d.left, d.right, d.caseLevel]
                .map { $0.map(String.init) ?? "—" }
            return parts.joined(separator: "/")
        }
        if let m = d.main { return "\(m)%" }
        if let l = d.left { return "\(l)%" }
        return "—"
    }

    @ViewBuilder
    private func caffeineRow(status: SystemStatusFeature) -> some View {
        let enabled = UserDefaults.standard.object(forKey: "notchy.indicatorCaffeineEnabled") as? Bool ?? true
        if enabled, status.isCaffeinated {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Keep awake")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Text("⌘⌥K to toggle")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func chargingRow(status: SystemStatusFeature) -> some View {
        let chargingEnabled = UserDefaults.standard.object(forKey: "notchy.indicatorChargingEnabled") as? Bool ?? true
        if chargingEnabled, status.isCharging, let watts = status.chargingWatts {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                Text("\(watts)W")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(adapterLabel(watts: watts))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
            }
        }
    }

    private func adapterLabel(watts: Int) -> String {
        switch watts {
        case ..<35:  return "trickle"
        case 35..<50: return "MagSafe"
        case 50..<70: return "PD fast"
        default:     return "PD max"
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.red)
                .frame(width: 5, height: 5)
            Text("LIVE")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.red)
                .tracking(0.5)
        }
    }

    @ViewBuilder
    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .frame(width: 18)
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(0.8)
            }
        }
    }

    private var cpuColor: Color {
        switch snapshot.cpuPercent {
        case ..<40: return .white.opacity(0.7)
        case 40..<75: return .yellow
        default: return .orange
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: now)
    }

    private func batteryBucket(_ pct: Int) -> Int {
        switch pct {
        case 0..<25: return 25
        case 25..<50: return 25
        case 50..<75: return 50
        default: return 100
        }
    }
}

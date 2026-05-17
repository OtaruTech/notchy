import SwiftUI

/// Default hover-expanded content: clock + date + system stats + next event.
/// Shown when the user hovers the notch and no media is playing.
struct DashboardView: View {
    let nextEvent: EventVM?
    let snapshot: SystemSnapshot
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 20) {
            // Time + date column
            VStack(alignment: .leading, spacing: 4) {
                Text(timeString)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(dateString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Divider()
                .frame(width: 1, height: 64)
                .overlay(.white.opacity(0.12))

            // Next event / hint column
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT UP")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(0.8)
                if let ev = nextEvent {
                    Text(ev.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(ev.startTime) – \(ev.endTime)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("Nothing scheduled")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Drop a file or play music")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // System stats column (bigger icons, clear labels)
            VStack(alignment: .trailing, spacing: 6) {
                statRow(
                    icon: "cpu.fill",
                    iconColor: snapshot.cpuPercent > 70 ? .orange : .white.opacity(0.7),
                    label: "CPU",
                    value: "\(snapshot.cpuPercent)%"
                )
                if let bat = snapshot.batteryPercent {
                    statRow(
                        icon: snapshot.isCharging ? "battery.100.bolt" : "battery.\(batteryBucket(bat))",
                        iconColor: snapshot.isCharging ? .green : (bat < 20 ? .red : .white.opacity(0.7)),
                        label: snapshot.isCharging ? "Charging" : "Battery",
                        value: "\(bat)%"
                    )
                }
            }
        }
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 18)
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.5)
            }
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

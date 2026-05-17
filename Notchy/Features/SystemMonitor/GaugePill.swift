import SwiftUI

struct GaugePill: View {
    let snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 9))
                    .foregroundStyle(snapshot.cpuPercent > 70 ? .orange : .white.opacity(0.55))
                Text("CPU \(snapshot.cpuPercent)%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if let bat = snapshot.batteryPercent {
                HStack(spacing: 3) {
                    Image(systemName: snapshot.isCharging ? "battery.100.bolt" : "battery.\(batteryBucket(bat))")
                        .font(.system(size: 9))
                        .foregroundStyle(snapshot.isCharging ? .green : (bat < 20 ? .red : .white.opacity(0.55)))
                    Text("\(bat)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.08))
        )
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

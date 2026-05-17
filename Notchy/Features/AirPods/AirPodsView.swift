import SwiftUI

struct AirPodsView: View {
    let vm: BTDeviceVM

    var body: some View {
        HStack(spacing: 18) {
            AirPodsIcon().frame(width: 120, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(vm.model).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 12) {
                    BatteryPill(label: "L", value: vm.battery.left)
                    BatteryPill(label: "R", value: vm.battery.right)
                    BatteryPill(label: "Case", value: vm.battery.caseLevel)
                }
                .padding(.top, 8)
            }
            Spacer()
        }
    }
}

private struct AirPodsIcon: View {
    var body: some View {
        HStack(spacing: 4) {
            Pod().rotationEffect(.degrees(-8))
            Pod().rotationEffect(.degrees(8))
        }
    }
}

private struct Pod: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(LinearGradient(colors: [.white, Color(white: 0.8)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 18, height: 42)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 14, height: 14)
            }
    }
}

private struct BatteryPill: View {
    let label: String
    let value: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(width: 60, height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [.green, Color(red: 0.13, green: 0.77, blue: 0.37)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 60 * CGFloat(value ?? 0) / 100, height: 6)
            }
            Text(value.map { "\($0)%" } ?? "—")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

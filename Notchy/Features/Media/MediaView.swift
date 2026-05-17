import SwiftUI
import AppKit

struct MediaView: View {
    let vm: NowPlayingVM
    var onPlayPause: () -> Void = {}
    var onPrev: () -> Void = {}
    var onNext: () -> Void = {}
    var onArtworkTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            ArtworkView(data: vm.artworkData, isPlaying: vm.isPlaying)
                .frame(width: 96, height: 96)
                .onTapGesture { onArtworkTap() }
                .help("Show source app")

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !vm.artist.isEmpty {
                    Text(vm.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                if !vm.album.isEmpty {
                    Text(vm.album)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                ScrubberView(progress: vm.progress)
                    .padding(.top, 6)
                HStack {
                    Text(formatTime(vm.elapsed)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(formatTime(vm.duration)).foregroundStyle(.white.opacity(0.5))
                }
                .font(.system(size: 10))
            }

            HStack(spacing: 14) {
                Image(systemName: "backward.fill")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .onTapGesture { onPrev() }
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                }
                .frame(width: 42, height: 42)
                .contentShape(Circle())
                .onTapGesture { onPlayPause() }
                Image(systemName: "forward.fill")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .onTapGesture { onNext() }
            }
            .foregroundStyle(.white)
            .font(.system(size: 13))
        }
    }

    private func formatTime(_ t: Double) -> String {
        guard t > 0 else { return "—" }
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Album artwork or fallback gradient. If real artwork is available, decode the
/// JPEG/PNG bytes via NSImage; otherwise show a deterministic gradient.
private struct ArtworkView: View {
    let data: Data?
    let isPlaying: Bool

    var body: some View {
        ZStack {
            if let data, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.pink, .purple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .purple.opacity(0.5), radius: 12, y: 4)
            }
        }
        .scaleEffect(isPlaying ? 1.0 : 0.92)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPlaying)
    }
}

private struct ScrubberView: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(height: 3)
                Capsule()
                    .fill(LinearGradient(colors: [.pink, .purple],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
    }
}

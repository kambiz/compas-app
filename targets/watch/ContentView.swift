import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: RemoteModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var crownFocused: Bool

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .noPlayer:
                message("Open compás on your iPhone and connect to your player", symbol: "iphone")
            case .phoneUnreachable:
                message("iPhone not reachable. Keep it nearby with compás open.", symbol: "iphone.slash")
            case .pinRejected:
                message("Check the PIN in the iPhone app", symbol: "lock.trianglebadge.exclamationmark")
            case .error(let text):
                message(text, symbol: "exclamationmark.triangle")
            case .ready(let track, let isPlaying, let volume):
                player(track: track, isPlaying: isPlaying, volume: volume)
            }
        }
        .onAppear { model.setActive(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in model.setActive(phase == .active) }
        .onChange(of: model.session.isReachable) { _, reachable in
            if reachable { Task { await model.refresh() } }
        }
    }

    private func message(_ text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary)
            Text(text).font(.footnote).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
    }

    private func player(track: TrackInfo?, isPlaying: Bool, volume: Int) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 1) {
                Text(track?.title ?? "Nothing playing")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                if let artist = track?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button { model.previous() } label: { Image(systemName: "backward.fill") }
                    .accessibilityLabel("Previous track")
                Button { model.togglePlayPause() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.title3)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                Button { model.next() } label: { Image(systemName: "forward.fill") }
                    .accessibilityLabel("Next track")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)

            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill").font(.caption2)
                ProgressView(value: Double(volume), total: 100)
                Text("\(volume)%").font(.caption2).monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(volume) percent")
        }
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($model.volume, from: 0, through: 100, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: model.volume) { _, _ in model.crownChanged() }
        .onAppear { crownFocused = true }
    }
}

import SwiftUI
import Combine

struct TrackInfo: Equatable {
    var title: String
    var artist: String
    var album: String
}

enum RemoteState: Equatable {
    case loading
    case noPlayer
    case phoneUnreachable
    case pinRejected
    case error(String)
    case ready(track: TrackInfo?, isPlaying: Bool, volumePercent: Int)
}

@MainActor
final class RemoteModel: ObservableObject {
    @Published private(set) var state: RemoteState = .loading
    /// Bound to the Digital Crown; 0...100.
    @Published var volume: Double = 50

    let session = WatchSession()

    private var sessionObserver: AnyCancellable?
    private var lastRemotePercent = -1
    /// The volume the watch last sent or took from the player. Crown changes equal to it are the
    /// watch's own status sync, not the user, so they aren't sent.
    private var crownBaseline = -1
    /// The player takes a few seconds to report a volume we just sent; until it does (or 6 s pass),
    /// older status volumes are ignored so the gauge doesn't jump back.
    private var pendingVolume: (percent: Int, until: Date)?
    private var pollTask: Task<Void, Never>?
    private var volumeTask: Task<Void, Never>?
    private var isActive = false
    private var refreshing = false
    /// Player told us to back off (HTTP 429); no requests before this time.
    private var holdoff: Date = .distantPast
    /// Ignore status volume briefly after the user turned the crown, so the gauge doesn't jump back.
    private var volumeTouchedAt: Date = .distantPast
    private let launchedAt = Date()

    init() {
        // Re-publish session changes (reachability, application context) to the views.
        sessionObserver = session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: Lifecycle

    func setActive(_ active: Bool) {
        isActive = active
        pollTask?.cancel()
        pollTask = nil
        guard active else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: Status

    func refresh() async {
        guard !refreshing else { return }
        guard Date() >= holdoff else { return }
        refreshing = true
        defer { refreshing = false }

        if session.hasPlayer == false {
            state = .noPlayer
            return
        }
        do {
            let reply = try await session.send(op: "status")
            apply(reply: reply)
        } catch {
            if case .ready = state, !(error is WatchSessionError) { return }
            // WatchConnectivity takes a few seconds to activate and find the iPhone after launch;
            // keep showing the spinner for that long instead of an "unreachable" error.
            if state == .loading, error is WatchSessionError, Date() < launchedAt.addingTimeInterval(10) { return }
            state = .phoneUnreachable
        }
    }

    private func apply(reply: [String: Any]) {
        if let err = reply["error"] as? String {
            switch err {
            case "no_player": state = .noPlayer
            case "network": state = .error("Can't reach your player. Is it on the same Wi-Fi?")
            default: state = .error((reply["message"] as? String) ?? "Something went wrong.")
            }
            return
        }
        let code = (reply["code"] as? NSNumber)?.intValue ?? 0
        let body = (reply["body"] as? String) ?? ""
        switch code {
        case 200..<300:
            parse(body: body)
        case 401:
            state = .pinRejected
        case 429:
            // Same shape the iPhone app reads: JSON `retryAfterSeconds`, clamped to 1...3600, default 60.
            let json = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any]
            var seconds = 60
            if let raw = json?["retryAfterSeconds"] {
                if let n = raw as? NSNumber { seconds = n.intValue }
                else if let s = raw as? String, let n = Int(s) { seconds = n }
            }
            seconds = max(1, min(seconds, 3600))
            holdoff = Date().addingTimeInterval(TimeInterval(seconds))
            state = .error("Too many attempts. Try again in \(seconds) s.")
        case 503:
            // Busy for a moment. Keep showing what we have; the next poll will catch up.
            if case .ready = state { return }
            state = .error("Player is busy. Try again.")
        default:
            state = .error("Player returned HTTP \(code).")
        }
    }

    private func parse(body: String) {
        guard let json = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any] else {
            state = .error("Unexpected reply from player.")
            return
        }
        // Mirrors src/data/parsePlaybackStatus.ts.
        let title = Self.string(json["title"])
        let track = title.isEmpty ? nil : TrackInfo(title: title, artist: Self.string(json["artist"]), album: Self.string(json["album"]))
        let playing = Self.bool(json["playing"])
        // volume is 0...1 (normalizedVolume in sessionPlayback.ts); missing -> 0, non-finite -> 0.68.
        let raw = (json["volume"] as? NSNumber)?.doubleValue ?? 0
        let norm = raw.isFinite ? max(0, min(1, raw)) : 0.68
        let percent = Int((norm * 100).rounded())
        if let pending = pendingVolume, percent != pending.percent, Date() < pending.until {
            // Stale: the player hasn't applied our last volume yet.
        } else if Date().timeIntervalSince(volumeTouchedAt) > 2.5 {
            pendingVolume = nil
            crownBaseline = percent
            if Int(volume.rounded()) != percent { volume = Double(percent) }
        }
        lastRemotePercent = percent
        state = .ready(track: track, isPlaying: playing, volumePercent: Int(volume.rounded()))
    }

    private static func string(_ v: Any?) -> String {
        guard let v, !(v is NSNull) else { return "" }
        return "\(v)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Same as jsonBoolean in remoteApiProtocol.ts.
    private static func bool(_ v: Any?) -> Bool {
        if let n = v as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
        if let s = v as? String { return s.lowercased() == "true" }
        return false
    }

    // MARK: Commands

    func togglePlayPause() {
        if case .ready(let track, let playing, let vol) = state {
            state = .ready(track: track, isPlaying: !playing, volumePercent: vol)
        }
        command("toggle")
    }

    func next() { command("next") }
    func previous() { command("prev") }

    private func command(_ op: String) {
        Task {
            do {
                let reply = try await session.send(op: op)
                if (reply["code"] as? NSNumber)?.intValue == 503 {
                    // Say so, then show the player's real state again (this also undoes the
                    // optimistic play/pause icon if the press didn't take).
                    state = .error("Player is busy. Try again.")
                    try? await Task.sleep(for: .seconds(2))
                    await refresh()
                    return
                }
                if reply["error"] != nil || ((reply["code"] as? NSNumber)?.intValue ?? 0) >= 300 {
                    apply(reply: reply)
                    return
                }
            } catch {
                state = .phoneUnreachable
                return
            }
            // Give the player a moment to settle before reading back.
            try? await Task.sleep(for: .milliseconds(250))
            await refresh()
        }
    }

    func crownChanged() {
        // Ignore changes we made ourselves when syncing from the player's status.
        guard Int(volume.rounded()) != crownBaseline else { return }
        // Until the first status arrives the crown sits at a placeholder; don't send that as a volume.
        guard lastRemotePercent >= 0 else { return }
        volumeTouchedAt = Date()
        if case .ready(let track, let playing, _) = state {
            state = .ready(track: track, isPlaying: playing, volumePercent: Int(volume.rounded()))
        }
        volumeTask?.cancel()
        volumeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            let percent = Int(self.volume.rounded())
            self.crownBaseline = percent
            self.pendingVolume = (percent, Date().addingTimeInterval(6))
            _ = try? await self.session.send(op: "volume", extra: ["percent": percent])
        }
    }
}

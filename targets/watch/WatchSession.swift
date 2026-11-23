import Foundation
import WatchConnectivity

enum WatchSessionError: Error {
    case unreachable
    case notActivated
    case malformedReply
}

/// Thin WatchConnectivity wrapper: the watch only ever talks to the iPhone, never to the player.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isReachable = false
    /// nil until the phone has published its context.
    @Published private(set) var hasPlayer: Bool?
    @Published private(set) var host = ""

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let wc = WCSession.default
        wc.delegate = self
        wc.activate()
    }

    func send(op: String, extra: [String: Any] = [:]) async throws -> [String: Any] {
        let wc = WCSession.default
        guard wc.activationState == .activated else { throw WatchSessionError.notActivated }
        guard wc.isReachable else { throw WatchSessionError.unreachable }
        var message = extra
        message["op"] = op
        return try await withCheckedThrowingContinuation { continuation in
            wc.sendMessage(message, replyHandler: { reply in
                nonisolated(unsafe) let reply = reply
                continuation.resume(returning: reply)
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    private func apply(context: [String: Any]) {
        if let has = context["hasPlayer"] as? Bool { hasPlayer = has }
        if let h = context["host"] as? String { host = h }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let context = session.receivedApplicationContext
        DispatchQueue.main.async {
            self.isReachable = reachable
            self.apply(context: context)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.isReachable = reachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(context: applicationContext) }
    }
}

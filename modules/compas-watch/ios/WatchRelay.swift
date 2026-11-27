import Foundation
import Security
import WatchConnectivity

/// The connected player's address and PIN, kept in the iPhone Keychain so the relay can answer the
/// watch even when iOS wakes the app in the background without starting React Native.
enum WatchPlayerStore {
  private static let service = "compas.watch-relay"
  private static let account = "player"

  struct Player: Codable {
    let address: String  // e.g. "http://192.168.1.20:8899"
    let pin: String?
  }

  static func save(_ player: Player) {
    guard let data = try? JSONEncoder().encode(player) else { return }
    clear()
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      // Background wake-ups happen while the phone may be locked.
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: data,
    ]
    SecItemAdd(query as CFDictionary, nil)
  }

  static func load() -> Player? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return try? JSONDecoder().decode(Player.self, from: data)
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

/// Receives commands from the watch app over WatchConnectivity and forwards them to the player.
///
/// Message contract (watch → phone, via `sendMessage(_:replyHandler:)`):
///   ["op": "status" | "toggle" | "next" | "prev" | "volume", "percent": Int (volume only)]
/// Reply:
///   ["code": Int (HTTP status), "body": String (response body, JSON for "status")]
///   or ["error": "no_player" | "bad_request" | "network", "message": String]
final class WatchRelay: NSObject, WCSessionDelegate {
  static let shared = WatchRelay()

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 8
    config.httpCookieStorage = nil
    config.urlCache = nil
    return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
  }()

  func activate() {
    guard WCSession.isSupported() else { return }
    let wc = WCSession.default
    if wc.delegate == nil { wc.delegate = self }
    if wc.activationState != .activated { wc.activate() }
  }

  /// Tells the watch whether a player is set up, without ever sending the PIN.
  func publishPlayerState() {
    guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
    let player = WatchPlayerStore.load()
    let host = player.flatMap { URL(string: $0.address)?.host } ?? ""
    try? WCSession.default.updateApplicationContext(["hasPlayer": player != nil, "host": host])
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated { publishPlayerState() }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Switching paired watches: reactivate for the new one.
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    handle(message, reply: replyHandler)
  }

  // MARK: Relay

  private func handle(_ message: [String: Any], reply: @escaping ([String: Any]) -> Void) {
    guard let player = WatchPlayerStore.load(), let base = URL(string: player.address) else {
      reply(["error": "no_player", "message": "Connect to a player in the iPhone app first."])
      return
    }
    guard let op = message["op"] as? String, let (method, path, query) = Self.route(op, message) else {
      reply(["error": "bad_request", "message": "Unsupported request."])
      return
    }
    var components = URLComponents(url: base.appendingPathComponent("api/v1" + path), resolvingAgainstBaseURL: false)
    if !query.isEmpty { components?.queryItems = query }
    guard let url = components?.url else {
      reply(["error": "bad_request", "message": "Invalid player address."])
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let pin = player.pin, !pin.isEmpty { request.setValue(pin, forHTTPHeaderField: "X-Compas-PIN") }

    // The player answers 503 while it is busy (for example right after a track change). A status
    // read is safe to repeat, so try it once more; commands are never repeated, because the player
    // may have acted on one before answering busy and a second play/pause would undo it.
    send(request, retryOnBusy: method == "GET", reply: reply)
  }

  private func send(_ request: URLRequest, retryOnBusy: Bool, reply: @escaping ([String: Any]) -> Void) {
    session.dataTask(with: request) { [weak self] data, response, error in
      if let error = error {
        reply(["error": "network", "message": error.localizedDescription])
        return
      }
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      if code == 503, retryOnBusy, let self = self {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
          self.send(request, retryOnBusy: false, reply: reply)
        }
        return
      }
      let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
      reply(["code": code, "body": body])
    }.resume()
  }

  /// Only these player calls are reachable from the watch.
  private static func route(_ op: String, _ message: [String: Any]) -> (String, String, [URLQueryItem])? {
    switch op {
    case "status": return ("GET", "/status", [])
    case "toggle": return ("POST", "/playback/toggle", [])
    case "next": return ("POST", "/playback/next", [])
    case "prev": return ("POST", "/playback/prev", [])
    case "volume":
      guard let percent = (message["percent"] as? NSNumber)?.intValue, (0...100).contains(percent) else { return nil }
      return ("POST", "/playback/volume", [URLQueryItem(name: "percent", value: String(percent))])
    default: return nil
    }
  }
}

/// The PIN header must never follow a redirect to another host.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

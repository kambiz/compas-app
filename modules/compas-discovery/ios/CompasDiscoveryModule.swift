import ExpoModulesCore
import Foundation
import Network
import Darwin

private let serviceType = "_compas-remote._tcp"
private let udpEnabled = true
private let udpPort: UInt16 = 8899
private let udpWindowSeconds = 4.0
private let udpIntervalSeconds = 1.0
private let udpRequest: [UInt8] = {
  var bytes = [UInt8](repeating: 0, count: 32)
  let text = Array("COMPAS_REMOTE_DISCOVER_V1".utf8)
  for (i, b) in text.enumerated() { bytes[i] = b }
  return bytes
}()
private let udpReply: [UInt8] = Array("COMPAS_REMOTE_V1 8899\n".utf8)

public class CompasDiscoveryModule: Module {
  private let queue = DispatchQueue(label: "com.compas.discovery")

  // All of the following is touched only on `queue`.
  private var generation: UInt64 = 0
  private var requestedScanId: Double?
  private var pausedForBackground = false
  private var browser: NWBrowser?
  private var connections: [String: NWConnection] = [:]
  private var seenServices = Set<String>()
  private var udpSocketFd: Int32 = -1

  public func definition() -> ModuleDefinition {
    Name("CompasDiscovery")

    Events("onDeviceFound", "onDeviceLost", "onDiscoveryStarted", "onDiscoveryStopped", "onDiscoveryError")

    AsyncFunction("startDiscovery") { (scanId: Double) -> Bool in
      self.queue.sync {
        if self.requestedScanId != scanId { self.stopLocked(emitStopped: false) }
        self.requestedScanId = scanId
        self.pausedForBackground = false
        self.startLocked(scanId: scanId)
      }
      return true
    }

    AsyncFunction("stopDiscovery") { () -> Bool in
      self.queue.sync {
        self.requestedScanId = nil
        self.pausedForBackground = false
        self.stopLocked(emitStopped: true)
      }
      return true
    }

    OnAppEntersBackground {
      self.queue.sync {
        if self.requestedScanId != nil && !self.pausedForBackground {
          self.pausedForBackground = true
          self.stopLocked(emitStopped: false)
        }
      }
    }

    OnAppEntersForeground {
      self.queue.sync {
        if self.pausedForBackground {
          self.pausedForBackground = false
          if let id = self.requestedScanId { self.startLocked(scanId: id) }
        }
      }
    }

    OnDestroy {
      self.queue.sync {
        self.requestedScanId = nil
        self.stopLocked(emitStopped: false)
      }
    }
  }

  // MARK: - Lifecycle (call on queue)

  private func startLocked(scanId: Double) {
    if browser == nil { startBonjourLocked(scanId: scanId) }
    if udpEnabled && udpSocketFd < 0 { startUdpLocked(scanId: scanId) }
  }

  private func stopLocked(emitStopped: Bool) {
    generation &+= 1
    let hadBrowser = browser != nil
    browser?.stateUpdateHandler = nil
    browser?.browseResultsChangedHandler = nil
    browser?.cancel()
    browser = nil
    for (_, c) in connections {
      c.stateUpdateHandler = nil
      c.cancel()
    }
    connections.removeAll()
    seenServices.removeAll()
    if udpSocketFd >= 0 {
      let fd = udpSocketFd
      udpSocketFd = -1
      Darwin.shutdown(fd, SHUT_RDWR)
      Darwin.close(fd)
    }
    if emitStopped && hadBrowser {
      sendEvent("onDiscoveryStopped", ["serviceType": serviceType + "."])
    }
  }

  // MARK: - Bonjour

  private func startBonjourLocked(scanId: Double) {
    generation &+= 1
    let gen = generation
    let params = NWParameters()
    params.includePeerToPeer = false
    let newBrowser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: params)
    browser = newBrowser

    newBrowser.stateUpdateHandler = { [weak self] state in
      guard let self = self, gen == self.generation else { return }
      switch state {
      case .ready:
        self.sendEvent("onDiscoveryStarted", ["serviceType": serviceType + "."])
      case .failed(let error):
        self.failBonjourLocked(code: Self.errorCode(error))
      case .waiting(let error):
        // Typically local-network permission denied or no network yet; surface it but keep waiting.
        self.sendEvent("onDiscoveryError", ["errorCode": Self.errorCode(error), "phase": "start"])
      default:
        break
      }
    }

    newBrowser.browseResultsChangedHandler = { [weak self] _, changes in
      guard let self = self, gen == self.generation else { return }
      for change in changes {
        switch change {
        case .added(let result):
          self.handleFoundLocked(result, scanId: scanId, gen: gen)
        case .removed(let result):
          self.handleLostLocked(result, scanId: scanId)
        case .changed(_, let new, _):
          // Re-resolve only if we never resolved this service (e.g. earlier attempt failed).
          if case .service(let name, _, _, _) = new.endpoint, !self.seenServices.contains(name) {
            self.handleFoundLocked(new, scanId: scanId, gen: gen)
          }
        default:
          break
        }
      }
    }

    newBrowser.start(queue: queue)
  }

  private func failBonjourLocked(code: Int) {
    stopLocked(emitStopped: false)
    sendEvent("onDiscoveryError", ["errorCode": code, "phase": "start"])
  }

  private static func errorCode(_ error: NWError) -> Int {
    switch error {
    case .posix(let c): return Int(c.rawValue)
    case .dns(let c): return Int(c)
    default: return -1
    }
  }

  private func handleLostLocked(_ result: NWBrowser.Result, scanId: Double) {
    guard case .service(let name, _, _, _) = result.endpoint else { return }
    if let conn = connections.removeValue(forKey: name) {
      conn.stateUpdateHandler = nil
      conn.cancel()
    }
    seenServices.remove(name)
    sendEvent("onDeviceLost", ["scanId": scanId, "id": name, "name": name])
  }

  private func handleFoundLocked(_ result: NWBrowser.Result, scanId: Double, gen: UInt64) {
    guard case .service(let name, _, _, _) = result.endpoint else { return }
    if seenServices.contains(name) { return }
    seenServices.insert(name)

    var apiVersion = "1"
    if case .bonjour(let txt) = result.metadata, let api = txt.dictionary["api"], !api.isEmpty {
      apiVersion = api
    }

    let tcp = NWProtocolTCP.Options()
    tcp.connectionTimeout = 5
    let params = NWParameters(tls: nil, tcp: tcp)
    if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
      ip.version = .v4
    }
    let conn = NWConnection(to: result.endpoint, using: params)
    connections[name] = conn

    conn.stateUpdateHandler = { [weak self, weak conn] state in
      guard let self = self, let conn = conn, gen == self.generation else { return }
      switch state {
      case .ready:
        let remote = conn.currentPath?.remoteEndpoint
        conn.stateUpdateHandler = nil
        conn.cancel()
        self.connections.removeValue(forKey: name)
        if case .hostPort(let host, let port)? = remote, let ip = Self.ipv4String(host) {
          let p = Int(port.rawValue)
          self.sendEvent("onDeviceFound", [
            "scanId": scanId,
            "id": name,
            "name": name,
            "host": ip,
            "hostname": NSNull(),
            "port": p,
            "address": "\(ip):\(p)",
            "apiVersion": apiVersion,
          ])
        } else {
          self.seenServices.remove(name)
        }
      case .failed, .cancelled:
        conn.stateUpdateHandler = nil
        if self.connections[name] === conn {
          self.connections.removeValue(forKey: name)
          // Allow a later `.changed` / restart to retry.
          self.seenServices.remove(name)
        }
      default:
        break
      }
    }
    conn.start(queue: queue)
  }

  private static func ipv4String(_ host: NWEndpoint.Host) -> String? {
    switch host {
    case .ipv4(let addr):
      let b = [UInt8](addr.rawValue)
      guard b.count == 4 else { return nil }
      return "\(b[0]).\(b[1]).\(b[2]).\(b[3])"
    case .ipv6(let addr):
      // IPv4-mapped (::ffff:a.b.c.d) addresses.
      let b = [UInt8](addr.rawValue)
      if b.count == 16, b[0..<10].allSatisfy({ $0 == 0 }), b[10] == 0xff, b[11] == 0xff {
        return "\(b[12]).\(b[13]).\(b[14]).\(b[15])"
      }
      return nil
    case .name(let n, _):
      let stripped = n.split(separator: "%").first.map(String.init) ?? n
      let parts = stripped.split(separator: ".")
      return parts.count == 4 && parts.allSatisfy({ UInt8($0) != nil }) ? stripped : nil
    @unknown default:
      return nil
    }
  }

  // MARK: - UDP broadcast probe (best effort)

  private func startUdpLocked(scanId: Double) {
    let fd = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
    if fd < 0 { return }
    var on: Int32 = 1
    if setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size)) != 0 {
      Darwin.close(fd)
      return
    }
    var tv = timeval(tv_sec: 0, tv_usec: 200_000)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    udpSocketFd = fd
    let gen = generation

    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.runUdp(fd: fd, gen: gen, scanId: scanId)
    }
  }

  private func isCurrent(_ gen: UInt64) -> Bool {
    return queue.sync { gen == self.generation }
  }

  private func runUdp(fd: Int32, gen: UInt64, scanId: Double) {
    let deadline = Date().addingTimeInterval(udpWindowSeconds)
    var nextSend = Date.distantPast
    var seen = Set<String>()
    var buf = [UInt8](repeating: 0, count: udpReply.count + 1)

    var dest = sockaddr_in()
    dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    dest.sin_family = sa_family_t(AF_INET)
    dest.sin_port = udpPort.bigEndian
    dest.sin_addr.s_addr = INADDR_BROADCAST.bigEndian

    while Date() < deadline && isCurrent(gen) {
      if Date() >= nextSend {
        let sent = withUnsafePointer(to: &dest) { ptr -> Int in
          ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
            udpRequest.withUnsafeBytes { raw in
              sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
          }
        }
        // Broadcast is blocked without Apple's multicast entitlement; give up silently.
        if sent < 0 { break }
        nextSend = Date().addingTimeInterval(udpIntervalSeconds)
      }

      var src = sockaddr_in()
      var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
      let n = withUnsafeMutablePointer(to: &src) { ptr -> Int in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
          recvfrom(fd, &buf, buf.count, 0, sa, &srcLen)
        }
      }
      if n < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
        break
      }
      guard n == udpReply.count, Array(buf[0..<n]) == udpReply else { continue }

      let a = UInt32(bigEndian: src.sin_addr.s_addr)
      let b0 = Int((a >> 24) & 0xff), b1 = Int((a >> 16) & 0xff)
      let b2 = Int((a >> 8) & 0xff), b3 = Int(a & 0xff)
      let usable = b0 == 10 || (b0 == 172 && (16...31).contains(b1)) ||
        (b0 == 192 && b1 == 168) || (b0 == 169 && b1 == 254)
      let host = "\(b0).\(b1).\(b2).\(b3)"
      if !usable || !seen.insert(host).inserted { continue }
      if !isCurrent(gen) { break }

      sendEvent("onDeviceFound", [
        "scanId": scanId,
        "id": "udp:\(host)",
        "name": "Compas Remote Control",
        "host": host,
        "port": Int(udpPort),
        "address": "\(host):\(udpPort)",
        "apiVersion": "1",
      ])
    }

    queue.sync {
      if self.udpSocketFd == fd {
        self.udpSocketFd = -1
        Darwin.close(fd)
      }
    }
  }
}

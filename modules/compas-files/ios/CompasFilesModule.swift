import ExpoModulesCore
import Foundation

/// Upper bound for one folder selection so a mistaken pick of a huge folder stays bounded.
private let maxCollectedFiles = 10_000
private let maxWalkDepth = 16

private func storageError(_ message: String) -> Exception {
  Exception(name: "StorageAccessException", description: message, code: "ERR_STORAGE_ACCESS")
}

private func pathError(_ message: String) -> Exception {
  Exception(name: "InvalidPathException", description: message, code: "ERR_INVALID_PATH")
}

public class CompasFilesModule: Module {
  private let transfers = PinSafeTransfers()

  /// The app sandbox's Documents folder, which the Files app and Finder file sharing expose to the user.
  private var documentsURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  /// Folders the app keeps in Documents for its own data (expo-sqlite catalog, synced cover cache).
  /// Flagging them hidden keeps them out of the Files app, which only needs to show Music.
  private static let internalFolders = ["SQLite", "synced-covers"]

  private func hideInternalFolders() {
    for name in Self.internalFolders {
      var url = documentsURL.appendingPathComponent(name, isDirectory: true)
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      var values = URLResourceValues()
      values.isHidden = true
      try? url.setResourceValues(values)
    }
  }

  public func definition() -> ModuleDefinition {
    Name("CompasFiles")

    OnCreate {
      self.hideInternalFolders()
    }

    Events("onUploadProgress")

    AsyncFunction("uploadFile") { (taskId: String, url: String, fileUri: String, headers: [String: String], promise: Promise) in
      let file: URL
      do { file = try Self.fileURL(fileUri) } catch { promise.reject(error); return }
      self.transfers.upload(taskId: taskId, url: url, file: file, headers: headers, onProgress: { sent, total in
        self.sendEvent("onUploadProgress", ["taskId": taskId, "sent": Double(sent), "total": Double(total)])
      }) { result in
        switch result {
        case .success(let (status, body)): promise.resolve(["status": status, "body": body])
        case .failure(let error): promise.reject(error)
        }
      }
    }

    AsyncFunction("downloadFile") { (taskId: String, url: String, fileUri: String, headers: [String: String], promise: Promise) in
      let file: URL
      do { file = try Self.fileURL(fileUri) } catch { promise.reject(error); return }
      self.transfers.download(taskId: taskId, url: url, file: file, headers: headers) { result in
        switch result {
        case .success(let (status, responseHeaders, errorBody)):
          promise.resolve(["status": status, "headers": responseHeaders, "errorBody": errorBody])
        case .failure(let error): promise.reject(error)
        }
      }
    }

    Function("cancelTransfer") { (taskId: String) in
      self.transfers.cancel(taskId)
    }

    // The app sandbox needs no grant: Documents is always readable and writable.
    Function("hasStorageAccess") { () -> Bool in true }
    Function("usesAllFilesAccess") { () -> Bool in false }
    Function("openAllFilesAccessSettings") { () -> Bool in false }

    // Documents also holds the app's own data (SQLite catalog, synced covers), so transfers
    // browse a dedicated Music folder, which shows up as "compás › Music" in the Files app.
    Function("getRoots") { () -> [[String: Any]] in
      let music = self.documentsURL.appendingPathComponent("Music", isDirectory: true)
      try? FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
      self.hideInternalFolders()
      return [["name": "On this iPhone", "path": music.path, "removable": false]]
    }

    AsyncFunction("listDirectory") { (path: String, showHidden: Bool) -> [[String: Any]] in
      let directory = try self.resolveDirectory(path)
      let children: [URL]
      do {
        children = try FileManager.default.contentsOfDirectory(
          at: directory, includingPropertiesForKeys: nil, options: [])
      } catch {
        throw storageError("Could not read \(directory.lastPathComponent)")
      }
      return children
        .filter { showHidden || !$0.lastPathComponent.hasPrefix(".") }
        .map { (url: $0, dir: Self.isDirectory($0)) }
        .sorted { a, b in
          if a.dir != b.dir { return a.dir }
          return a.url.lastPathComponent.lowercased() < b.url.lastPathComponent.lowercased()
        }
        .map { self.entry(of: $0.url, isDirectory: $0.dir) }
    }

    /// Expands selected files and folders into a flat upload list; folders keep their own name as the top level.
    AsyncFunction("collectFiles") { (paths: [String], showHidden: Bool) -> [[String: Any]] in
      var collected: [[String: Any]] = []
      for path in paths {
        let file = try self.resolveExisting(path)
        if Self.isDirectory(file) {
          try self.walk(file, relativeDir: file.lastPathComponent, depth: 0, out: &collected, showHidden: showHidden)
        } else {
          try self.addFile(file, relativeDir: "", out: &collected)
        }
      }
      return collected
    }
  }

  // MARK: - Paths

  /// Decodes a file:// URI (percent-encoded per segment by the JS side) to a file URL.
  static func fileURL(_ fileUri: String) throws -> URL {
    guard let parsed = URL(string: fileUri), parsed.scheme == "file" else {
      guard fileUri.hasPrefix("/") else { throw pathError("Expected a file URI") }
      return URL(fileURLWithPath: fileUri)
    }
    let path = parsed.path  // URL.path is percent-decoded
    guard !path.isEmpty else { throw pathError("Expected a file URI") }
    return URL(fileURLWithPath: path)
  }

  private func canonical(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  private func isWithinDocuments(_ url: URL) -> Bool {
    let root = canonical(documentsURL)
    let path = canonical(url)
    return path == root || path.hasPrefix(root + "/")
  }

  private static func isDirectory(_ url: URL) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
  }

  private func resolveExisting(_ path: String) throws -> URL {
    guard path.hasPrefix("/") else { throw pathError("Expected an absolute path") }
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path), isWithinDocuments(url) else {
      throw pathError("\(url.lastPathComponent) is not available")
    }
    return url
  }

  private func resolveDirectory(_ path: String) throws -> URL {
    let url = try resolveExisting(path)
    guard Self.isDirectory(url) else { throw pathError("\(url.lastPathComponent) is not a folder") }
    return url
  }

  private func attributes(of url: URL) -> [FileAttributeKey: Any] {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
  }

  private func entry(of url: URL, isDirectory: Bool) -> [String: Any] {
    let attrs = attributes(of: url)
    let size = (attrs[.size] as? NSNumber)?.doubleValue ?? 0
    let modified = ((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) * 1000
    return [
      "name": url.lastPathComponent,
      "path": url.path,
      "isDirectory": isDirectory,
      "size": isDirectory ? 0.0 : size,
      "modified": modified.rounded(),
    ]
  }

  private func addFile(_ url: URL, relativeDir: String, out: inout [[String: Any]]) throws {
    if out.count >= maxCollectedFiles { throw storageError("Choose fewer than \(maxCollectedFiles) files at once") }
    let size = (attributes(of: url)[.size] as? NSNumber)?.doubleValue ?? 0
    out.append(["path": url.path, "name": url.lastPathComponent, "relativeDir": relativeDir, "size": size])
  }

  private func walk(_ directory: URL, relativeDir: String, depth: Int, out: inout [[String: Any]], showHidden: Bool) throws {
    if depth > maxWalkDepth { return }
    guard let children = try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil, options: []) else { return }
    let sorted = children
      .filter { showHidden || !$0.lastPathComponent.hasPrefix(".") }
      .map { (url: $0, dir: Self.isDirectory($0)) }
      .sorted { a, b in
        if a.dir != b.dir { return !a.dir }
        return a.url.lastPathComponent.lowercased() < b.url.lastPathComponent.lowercased()
      }
    for child in sorted {
      if child.dir {
        try walk(child.url, relativeDir: "\(relativeDir)/\(child.url.lastPathComponent)", depth: depth + 1, out: &out, showHidden: showHidden)
      } else {
        try addFile(child.url, relativeDir: relativeDir, out: &out)
      }
    }
  }
}

// MARK: - PIN-safe transfers

private func transferError(_ message: String) -> Exception {
  Exception(name: "TransferException", description: message, code: "ERR_TRANSFER")
}

private func cancelledError() -> Exception {
  Exception(name: "TransferCancelledException", description: "Transfer cancelled", code: "ERR_TRANSFER_CANCELLED")
}

private func destinationError(_ message: String) -> Exception {
  Exception(name: "TransferDestinationException", description: message, code: "ERR_TRANSFER_DESTINATION")
}

private let progressIntervalMs: Double = 100

private final class TransferState {
  let taskId: String
  var onProgress: ((Int64, Int64) -> Void)?
  var lastEmit: Double = 0
  // Upload
  var body = Data()
  var uploadDone: ((Result<(Int, String), Error>) -> Void)?
  // Download
  var destination: URL?
  var downloadDone: ((Result<(Int, [String: String], String), Error>) -> Void)?
  var status = 0
  var responseHeaders: [String: String] = [:]
  var errorBody = ""
  var failure: Error?

  init(taskId: String) { self.taskId = taskId }
}

/// Cancellable transfers by the task id the JavaScript side chose. Redirects are never followed:
/// the 3xx is returned to the caller, so the PIN header never leaves the player.
final class PinSafeTransfers: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
  private let lock = NSLock()
  private var states: [Int: TransferState] = [:]
  private var tasks: [String: URLSessionTask] = [:]
  private var cancelled = Set<String>()
  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 60
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    config.urlCache = nil
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return URLSession(configuration: config, delegate: self, delegateQueue: queue)
  }()

  func cancel(_ taskId: String) {
    lock.lock()
    cancelled.insert(taskId)
    let task = tasks[taskId]
    lock.unlock()
    task?.cancel()
  }

  func upload(taskId: String, url: String, file: URL, headers: [String: String], onProgress: @escaping (Int64, Int64) -> Void,
              done: @escaping (Result<(Int, String), Error>) -> Void) {
    guard let target = URL(string: url) else { done(.failure(transferError("Invalid URL"))); return }
    guard FileManager.default.isReadableFile(atPath: file.path) else {
      done(.failure(transferError("\(file.lastPathComponent) is not readable"))); return
    }
    var request = URLRequest(url: target)
    request.httpMethod = "POST"
    for (name, value) in headers where name.caseInsensitiveCompare("Content-Type") != .orderedSame {
      request.addValue(value, forHTTPHeaderField: name)
    }
    request.setValue(headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?.value
                     ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
    let task = session.uploadTask(with: request, fromFile: file)
    let state = TransferState(taskId: taskId)
    state.onProgress = onProgress
    state.uploadDone = done
    start(task, state)
  }

  func download(taskId: String, url: String, file: URL, headers: [String: String],
                done: @escaping (Result<(Int, [String: String], String), Error>) -> Void) {
    guard let target = URL(string: url) else { done(.failure(transferError("Invalid URL"))); return }
    var request = URLRequest(url: target)
    for (name, value) in headers { request.addValue(value, forHTTPHeaderField: name) }
    let task = session.downloadTask(with: request)
    let state = TransferState(taskId: taskId)
    state.destination = file
    state.downloadDone = done
    start(task, state)
  }

  private func start(_ task: URLSessionTask, _ state: TransferState) {
    lock.lock()
    states[task.taskIdentifier] = state
    tasks[state.taskId] = task
    let alreadyCancelled = cancelled.contains(state.taskId)
    lock.unlock()
    // A cancel that arrived before the task existed must still stop it.
    if alreadyCancelled { task.cancel() }
    task.resume()
  }

  private func state(for task: URLSessionTask) -> TransferState? {
    lock.lock(); defer { lock.unlock() }
    return states[task.taskIdentifier]
  }

  // MARK: Delegate

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)  // Never follow: the 3xx response is handed back as the result.
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                  totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    guard let state = state(for: task), let onProgress = state.onProgress else { return }
    let now = Date().timeIntervalSince1970 * 1000
    if totalBytesSent == totalBytesExpectedToSend || now - state.lastEmit >= progressIntervalMs {
      state.lastEmit = now
      onProgress(totalBytesSent, totalBytesExpectedToSend)
    }
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    state(for: dataTask)?.body.append(data)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let state = state(for: downloadTask), let http = downloadTask.response as? HTTPURLResponse else { return }
    state.status = http.statusCode
    var headers: [String: String] = [:]
    for (key, value) in http.allHeaderFields {
      let name = "\(key)".lowercased()
      if headers[name] == nil { headers[name] = "\(value)" }
    }
    state.responseHeaders = headers
    if (200..<300).contains(http.statusCode) {
      guard let destination = state.destination else { return }
      do {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: location, to: destination)
      } catch {
        state.failure = destinationError(error.localizedDescription)
      }
    } else {
      let data = (try? Data(contentsOf: location)) ?? Data()
      state.errorBody = String(decoding: data, as: UTF8.self)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    let state = states.removeValue(forKey: task.taskIdentifier)
    if let state = state {
      tasks.removeValue(forKey: state.taskId)
      cancelled.remove(state.taskId)
    }
    lock.unlock()
    guard let state = state else { return }

    var failure: Error? = state.failure
    if failure == nil, let error = error {
      let isCancel = (error as? URLError)?.code == .cancelled
      failure = isCancel ? cancelledError() : transferError(error.localizedDescription)
    }
    if let done = state.uploadDone {
      if let failure = failure { return done(.failure(failure)) }
      let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
      done(.success((status, String(decoding: state.body, as: UTF8.self))))
    } else if let done = state.downloadDone {
      if let failure = failure { return done(.failure(failure)) }
      done(.success((state.status, state.responseHeaders, state.errorBody)))
    }
  }
}

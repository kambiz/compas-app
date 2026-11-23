import ExpoModulesCore

// TODO(Phase 2): implement PIN-safe uploads/downloads (URLSession that never follows redirects,
// see PinSafeHttp.kt) and local file browsing.
public class CompasFilesModule: Module {
  private static let notImplemented = "Not yet implemented on iOS"

  public func definition() -> ModuleDefinition {
    Name("CompasFiles")

    Events("onUploadProgress")

    AsyncFunction("uploadFile") { (taskId: String, url: String, fileUri: String, headers: [String: String]) -> [String: Any] in
      throw Exception(name: "ERR_NOT_IMPLEMENTED", description: Self.notImplemented)
    }

    AsyncFunction("downloadFile") { (taskId: String, url: String, fileUri: String, headers: [String: String]) -> [String: Any] in
      throw Exception(name: "ERR_NOT_IMPLEMENTED", description: Self.notImplemented)
    }

    Function("cancelTransfer") { (taskId: String) in
    }

    Function("hasStorageAccess") { () -> Bool in
      return false
    }

    Function("usesAllFilesAccess") { () -> Bool in
      return false
    }

    Function("openAllFilesAccessSettings") { () -> Bool in
      return false
    }

    Function("getRoots") { () -> [[String: Any]] in
      return []
    }

    AsyncFunction("listDirectory") { (path: String, showHidden: Bool) -> [[String: Any]] in
      throw Exception(name: "ERR_NOT_IMPLEMENTED", description: Self.notImplemented)
    }

    AsyncFunction("collectFiles") { (paths: [String], showHidden: Bool) -> [[String: Any]] in
      throw Exception(name: "ERR_NOT_IMPLEMENTED", description: Self.notImplemented)
    }
  }
}

import ExpoModulesCore
import Foundation

// Stub: in-app updates are Android only; iOS updates go through the App Store / TestFlight.
public class CompasUpdatesModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CompasUpdates")

    AsyncFunction("fetchAppUpdateManifest") { (channel: String) -> [String: Any] in
      throw Exception(name: "ERR_UNSUPPORTED", description: "Application updates are not supported on iOS")
    }

    Function("getDeviceApiLevel") { () -> Int in
      return 0
    }

    Function("canInstallAppUpdates") { () -> Bool in
      return false
    }

    Function("openAppUpdatePermissionSettings") { () in
    }

    AsyncFunction("installAppUpdate") { (url: String, hash: String, versionCode: Double, size: Double) in
      throw Exception(name: "ERR_UNSUPPORTED", description: "Application updates are not supported on iOS")
    }

    Function("getAppVersion") { () -> [String: Any] in
      let info = Bundle.main.infoDictionary ?? [:]
      let version = info["CFBundleShortVersionString"] as? String ?? ""
      let build = Int(info["CFBundleVersion"] as? String ?? "") ?? 0
      return ["version": version, "versionCode": build]
    }

    Function("notificationsEnabled") { () -> Bool in
      return false
    }

    Function("notifyRelease") { (kind: String, version: String, url: String) -> Bool in
      return false
    }
  }
}

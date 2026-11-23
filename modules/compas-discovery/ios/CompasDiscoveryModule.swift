import ExpoModulesCore

// TODO(Phase 2): implement with Bonjour (NWBrowser on `_compas-remote._tcp`) and emit
// onDeviceFound / onDeviceLost / onDiscoveryStarted / onDiscoveryStopped / onDiscoveryError.
public class CompasDiscoveryModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CompasDiscovery")

    Events("onDeviceFound", "onDeviceLost", "onDiscoveryStarted", "onDiscoveryStopped", "onDiscoveryError")

    AsyncFunction("startDiscovery") { (scanId: Double) -> Bool in
      return true
    }

    AsyncFunction("stopDiscovery") { () -> Bool in
      return true
    }
  }
}

import ExpoModulesCore

// Stub: Bluetooth Classic RFCOMM is not available to iOS apps.
public class CompasBluetoothModule: Module {
  private static let unsupported = "Bluetooth is not supported on iOS"

  public func definition() -> ModuleDefinition {
    Name("CompasBluetooth")

    Events("onDeviceFound", "onBondStateChanged", "onDiscoveryFinished")

    AsyncFunction("getBondedDevices") { () -> [[String: Any]] in
      return []
    }

    AsyncFunction("startDiscovery") { (scanId: Double) -> Bool in
      return false
    }

    AsyncFunction("stopDiscovery") { () -> Bool in
      return true
    }

    AsyncFunction("pairDevice") { (deviceId: String) -> Bool in
      throw Exception(name: "ERR_UNSUPPORTED", description: Self.unsupported)
    }

    AsyncFunction("preemptArtwork") { (index: Double?) -> Int in
      return 0
    }

    AsyncFunction("resetPairingBlock") { (deviceId: String) -> Bool in
      return false
    }

    AsyncFunction("executeRfcommRequest") { (deviceId: String, method: String, target: String, headers: [String: String]?, isArtwork: Bool, artworkIndex: Double?, bodyBase64: String?) -> [String: Any] in
      throw Exception(name: "ERR_UNSUPPORTED", description: Self.unsupported)
    }
  }
}

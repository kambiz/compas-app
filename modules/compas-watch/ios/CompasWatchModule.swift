import ExpoModulesCore

/// JS-facing side of the watch relay: the app reports the connected Wi-Fi player here.
public class CompasWatchModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CompasWatch")

    OnCreate {
      WatchRelay.shared.activate()
    }

    Function("setPlayer") { (address: String, pin: String?) in
      WatchPlayerStore.save(.init(address: address, pin: pin))
      WatchRelay.shared.publishPlayerState()
    }

    Function("clearPlayer") {
      WatchPlayerStore.clear()
      WatchRelay.shared.publishPlayerState()
    }
  }
}

/// Starts WatchConnectivity at launch, including background launches triggered by the watch,
/// where no scene (and so no React Native) is created.
public class CompasWatchAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func application(_ application: UIApplication,
                          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    WatchRelay.shared.activate()
    return true
  }
}

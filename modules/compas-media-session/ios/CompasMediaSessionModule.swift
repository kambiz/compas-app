import ExpoModulesCore

// TODO(Phase 3): lock-screen / Control Center controls via MPNowPlayingInfoCenter and MPRemoteCommandCenter.
public class CompasMediaSessionModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CompasMediaSession")

    Events("onMediaAction", "onBackgroundTick")

    AsyncFunction("updatePlayback") { (update: [String: Any]) -> Bool in
      return true
    }

    AsyncFunction("updateMetadata") { (update: [String: Any]) -> Bool in
      return true
    }

    AsyncFunction("clearState") { () -> Bool in
      return true
    }

    AsyncFunction("startPlaybackService") { (message: String?) -> Bool in
      return true
    }

    AsyncFunction("stopPlaybackService") { () -> Bool in
      return true
    }
  }
}

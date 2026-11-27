import SwiftUI

@main
struct CompasWatchApp: App {
    @StateObject private var model = RemoteModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
#if DEBUG
                .task { await WatchSelfTest.runIfRequested(model) }
#endif
        }
    }
}

#if DEBUG
/// Debug builds only. The watch Simulator can't be tapped from scripts, so launching with
/// `-selfTest` presses each control in code: the same calls the buttons and Digital Crown make.
/// `xcrun simctl launch --console-pty <watch> <bundle-id> -selfTest`
@MainActor
enum WatchSelfTest {
    static func runIfRequested(_ model: RemoteModel) async {
        guard ProcessInfo.processInfo.arguments.contains("-selfTest") else { return }
        func step(_ name: String, wait seconds: Double = 5, _ action: () -> Void) async {
            print("SELFTEST \(name)")
            action()
            try? await Task.sleep(for: .seconds(seconds))
            print("SELFTEST after \(name): \(model.state)")
        }
        // Start only once the player's real status (and volume) has arrived, so the crown steps
        // return the volume to where it was rather than to the placeholder.
        for _ in 0..<30 {
            if case .ready = model.state { break }
            try? await Task.sleep(for: .seconds(1))
        }
        guard case .ready(_, _, let startPercent) = model.state else {
            print("SELFTEST aborted: \(model.state)")
            return
        }
        print("SELFTEST start: \(model.state)")
        let startVolume = Double(startPercent)
        await step("toggle") { model.togglePlayPause() }
        await step("next") { model.next() }
        await step("previous") { model.previous() }
        await step("crown +3") { model.volume = startVolume + 3; model.crownChanged() }
        await step("crown back") { model.volume = startVolume; model.crownChanged() }
        await step("toggle back") { model.togglePlayPause() }
        print("SELFTEST done")
    }
}
#endif

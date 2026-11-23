import SwiftUI

@main
struct CompasWatchApp: App {
    @StateObject private var model = RemoteModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}

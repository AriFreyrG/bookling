import SwiftUI

@main
struct AudiobookApp: App {
    @StateObject private var library = LibraryViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                library.saveProgress()
            }
        }
    }
}

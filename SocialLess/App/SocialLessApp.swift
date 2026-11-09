import SwiftUI

@main
struct SocialLessApp: App {
    @State private var container: AppContainer?
    @State private var loadFailed = false
    var body: some Scene {
        WindowGroup {
            Group {
                if let container { RootView(container: container) }
                else if loadFailed {
                    ContentUnavailableView {
                        Label("Unable to open local data", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your existing data has been kept. Close and reopen SocialLess, or try again.")
                    } actions: {
                        Button("Try again", action: load)
                    }
                } else { ProgressView("Opening SocialLess…") }
            }
            .tint(Theme.accent)
            .task { if container == nil { load() } }
        }
    }
    private func load() {
        do { container = try AppContainer.live(); loadFailed = false }
        catch { loadFailed = true }
    }
}



import SwiftUI

struct RootView: View {
    @Bindable var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var platform: SocialPlatform?

    var body: some View {
        Group {
            if !container.settings.completedOnboarding {
                OnboardingView(container: container)
            } else {
                TabView {
                    NavigationStack { DashboardView(container: container) { platform = $0 } }
                        .tabItem { Label("Today", systemImage: "circle.grid.2x2") }
                    NavigationStack { InsightsView(container: container) }
                        .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
                    NavigationStack { SettingsView(container: container) }
                        .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                }
            }
        }
        .fullScreenCover(item: $platform, onDismiss: container.refreshHistory) { selected in
            SessionFlowView(container: container, platform: selected)
        }
        .onChange(of: scenePhase) { _, phase in
            container.engine.setSceneActive(phase == .active)
            if phase == .active { container.refreshHistory() }
        }
        .alert("SocialLess", isPresented: Binding(get: { container.notice != nil }, set: { if !$0 { container.notice = nil } })) {
            Button("OK") { container.notice = nil }
        } message: { Text(container.notice ?? "") }
    }
}


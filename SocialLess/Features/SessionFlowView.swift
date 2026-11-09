import SwiftUI

struct SessionFlowView: View {
    @Bindable var container: AppContainer
    let platform: SocialPlatform
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var intent: SessionIntent = .checkFriends
    @State private var minutes = 10
    @State private var mode: BrowsingMode = .demo
    @State private var error: String?
    @AccessibilityFocusState private var completionFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch container.engine.state {
                case .idle: setup
                case .active, .paused: BrowserView(engine: container.engine)
                case .completed(let summary): completion(summary)
                }
            }.background(Theme.background)
        }
        .interactiveDismissDisabled()
        .onAppear { minutes = container.settings.minutes(for: platform); mode = container.settings.defaultMode }
        .task {
            while !Task.isCancelled {
                container.engine.tick()
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
        }
        .alert("Couldn’t start session", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PlatformMark(platform: platform)
                Text("What brings\nyou here?").font(.largeTitle.bold())
                Text("Give this moment a purpose.").font(.title3).foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    ForEach(SessionIntent.allCases) { item in
                        Button { intent = item } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.symbol).frame(width: 26)
                                Text(item.title)
                                Spacer()
                                Image(systemName: intent == item ? "checkmark.circle.fill" : "circle")
                            }.font(.body.weight(.medium)).padding(18)
                                .background(intent == item ? Theme.accent.opacity(0.12) : Theme.card, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).foregroundStyle(intent == item ? Theme.accent : .primary)
                            .accessibilityAddTraits(intent == item ? .isSelected : [])
                            .accessibilityIdentifier("intent.\(item.rawValue)")
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Time for this session", selection: $minutes) {
                            ForEach(SessionConfiguration.allowedMinutes, id: \.self) { Text("\($0) minutes").tag($0) }
                        }.accessibilityIdentifier("session.duration")
                        Picker("Experience", selection: $mode) {
                            ForEach(BrowsingMode.allCases) { Text($0.title).tag($0) }
                        }.accessibilityIdentifier("session.mode")
                    }
                }
                Footnote(text: mode == .demo ? "A local sample page, with no real accounts or network access. Your timer and session history work just like a normal session." : PlatformCapability().notes)
                if mode == .website {
                    Footnote(text: "This opens the service’s standard website. SocialLess is independent of these services. Review their terms before use. If login is blocked, return to the demo; there is no bypass.")
                }
                PrimaryButton(title: mode == .demo ? "Start demo session" : "Start website session", action: start)
                    .accessibilityIdentifier("session.start")
                Footnote(text: "Your timer pauses when SocialLess is inactive. When time is up, browsing ends.")
            }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.navigationTitle(platform.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.accessibilityIdentifier("session.cancel") } }
    }

    private func completion(_ summary: SessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "sun.max").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(Theme.accent).accessibilityHidden(true)
                Text(summary.endReason == .timeLimitReached ? "Time’s up." : "A good place\nto pause.")
                    .font(.largeTitle.bold()).accessibilityIdentifier("session.completed")
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($completionFocused)
                Text("You checked in.\nNow make room for what’s next.").font(.title3).foregroundStyle(.secondary)
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(summary.platform.title, systemImage: summary.platform.symbol).font(.headline)
                        Text(summary.intent.title)
                        Text(TimeLabel.duration(summary.activeDurationSeconds) + " of active time").font(.title2.bold())
                        Text(summary.endReason.title).font(.subheadline).foregroundStyle(.secondary)
                        if summary.mode == .demo { Text("Offline demo session").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if container.engine.persistenceFailed {
                    Text("Browsing has ended, but your session could not be saved. Try saving again before leaving.")
                    Button("Retry saving") { container.engine.retryPersistence() }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                }
                PrimaryButton(title: "Done") {
                    container.engine.reset(); container.refreshHistory(); dismiss()
                }.disabled(container.engine.persistenceFailed).accessibilityIdentifier("session.done")
                Button("Start a new intentional session") {
                    container.engine.reset(); container.refreshHistory()
                }.frame(maxWidth: .infinity, minHeight: 44).disabled(container.engine.persistenceFailed)
            }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.navigationBarBackButtonHidden().onAppear { completionFocused = true }
    }
    private func start() {
        do {
            let configuration = try SessionConfiguration(platform: platform, intent: intent,
                duration: container.testSessionDuration ?? Double(minutes * 60), mode: mode)
            try container.engine.start(configuration, keepHistory: container.settings.keepHistory)
            container.engine.setSceneActive(scenePhase == .active)
        } catch { self.error = "The session could not start because local storage is unavailable. Your existing data has been kept." }
    }
}

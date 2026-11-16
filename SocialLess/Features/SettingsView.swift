import SwiftUI
import WebKit

struct SettingsView: View {
    @Bindable var container: AppContainer
    @State private var deleteHistory = false
    @State private var clearWebData = false
    @State private var resetSettings = false
    @State private var clearing = false
    @State private var cleared = false

    var body: some View {
        Form {
            Section("Your sessions") {
                Picker("Default experience", selection: $container.settings.defaultMode) {
                    ForEach(BrowsingMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Keep local session history", isOn: $container.settings.keepHistory).accessibilityIdentifier("settings.history")
                Picker("Weekly time intention", selection: $container.settings.weeklyGoalMinutes) {
                    ForEach([30, 60, 90, 120, 180, 240], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Footnote(text: "History is optional. Turning it off stops saving future sessions; existing history stays until you delete it.")
            }
            ForEach(SocialPlatform.allCases) { platform in
                Section(platform.title) {
                    Toggle("Show on dashboard", isOn: Binding(get: { container.settings.enabledPlatforms.contains(platform) }, set: { value in
                        if value { container.settings.enabledPlatforms.insert(platform) }
                        else { container.settings.enabledPlatforms.remove(platform) }
                    })).accessibilityIdentifier("settings.enabled.\(platform.rawValue)")
                    Picker("Session length", selection: Binding(get: { container.settings.minutes(for: platform) }, set: { container.settings.defaultMinutes[platform] = $0 })) {
                        ForEach(SessionConfiguration.allowedMinutes, id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    LabeledContent("Website", value: "Experimental")
                    LabeledContent("Website filters", value: platform == .instagram ? "Experimental · Reels / Explore" : "Unavailable")
                    if platform == .instagram {
                        NavigationLink("Import following list") { FollowingListView(store: container.followingStore) }
                            .accessibilityIdentifier("settings.following")
                        Footnote(text: "Start a website session, then open Filters to check and try hiding the Reels navigation link.")
                        if container.settings.filters(for: platform, mode: .website).rememberedRuleSetVersion != nil {
                            Button("Forget saved website filters") {
                                container.settings.setFilters(FilterPreferences(), for: platform, mode: .website)
                            }.accessibilityIdentifier("settings.forgetWebsiteFilters")
                            Footnote(text: "The next website session will start with filters off. This does not clear your website sign-in.")
                        }
                    }
                    NavigationLink("Try demo filters") {
                        FilterControlsView(platform: platform, mode: .demo,
                                           ruleSet: try? FilterRuleRegistry().rules(for: platform, mode: .demo),
                                           preferences: Binding(get: { container.settings.filters(for: platform, mode: .demo) },
                                                                set: { container.settings.setFilters($0, for: platform, mode: .demo) }))
                    }.accessibilityIdentifier("settings.filters.\(platform.rawValue)")
                }
            }
            Section("Capabilities") {
                Text("Timed browsing & experimental filters").font(.headline)
                Footnote(text: PlatformCapability().notes)
                LabeledContent("Native app shielding", value: "Unavailable")
                Footnote(text: "Screen Time requires a later release, entitlements and real iPhone testing. SocialLess does not restrict other apps.")
            }
            Section("Your data") {
                Button("Delete session history", role: .destructive) { deleteHistory = true }.accessibilityIdentifier("settings.deleteHistory")
                Button(clearing ? "Clearing website data…" : "Clear website login data", role: .destructive) { clearWebData = true }.disabled(clearing)
                Button("Reset preferences") { resetSettings = true }
                if cleared { Label("Website data cleared", systemImage: "checkmark.circle").font(.footnote) }
            }
            Section {
                NavigationLink("Privacy & limitations") { PrivacyView() }
                LabeledContent("Version", value: "0.1.0 · Personal prototype")
            }
        }.navigationTitle("Settings")
            .confirmationDialog("Delete all local session history?", isPresented: $deleteHistory, titleVisibility: .visible) {
                Button("Delete history", role: .destructive) { container.deleteHistory() }
            } message: { Text("This permanently removes SocialLess session records. Website logins and preferences stay unchanged.") }
            .confirmationDialog("Clear website login data?", isPresented: $clearWebData, titleVisibility: .visible) {
                Button("Clear website data", role: .destructive) {
                    clearing = true
                    Task { @MainActor in
                        let store = WKWebsiteDataStore.default()
                        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
                        clearing = false; cleared = true
                    }
                }
            } message: { Text("This signs you out of websites inside SocialLess and removes their cached data. It does not clear Safari, native apps or your session history.") }
            .confirmationDialog("Reset preferences?", isPresented: $resetSettings, titleVisibility: .visible) {
                Button("Reset preferences", role: .destructive) {
                    container.settings = AppSettings()
                    container.settings.completedOnboarding = true
                }
            } message: { Text("Restore demo mode, enabled platforms and default time limits. Your session history and website logins are kept.") }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("A quieter place to check in") {
                Text("SocialLess is an independent personal-use prototype. It is not affiliated with Instagram, Facebook or TikTok.")
                Text("It helps you set an intention and a time boundary inside this app. It cannot guarantee friends-only feeds, remove all recommendations, or modify native social apps.")
            }
            Section("On this device") {
                Text("With local history enabled, we store the platform, selected intention, demo/website mode, timestamps, active duration and end reason. There is no SocialLess account, backend or analytics SDK.")
                Text("We do not extract social passwords, login cookies or messages. If you import a following list, only its account names and import date are saved locally, excluded from backups. You can delete it separately. The experimental feed filter compares visible author links on-device without saving posts or author links. Website session data is managed separately by WebKit and the website. A website may collect data under its own privacy policy.")
                Text("History and website data can be deleted separately in Settings. Device backups may include app data under your system backup settings.")
            }
            Section("Honest boundaries") {
                Text("Website integrations remain experimental. Instagram browsing, timed expiry, retained sign-in and reversible Reels navigation filtering have been reported working on one iPhone; this does not guarantee every feature or account works. You can remember your filter choices after trying them. Each page is checked before remembered filters apply. Facebook and TikTok filters and native app shielding remain unavailable.")
                Text("If a service rejects embedded browsing, SocialLess offers its offline demo. It does not bypass login restrictions or open another app automatically.")
            }
            Section("How time works") {
                Text("Only foreground active time counts, including page loading and error screens. Inactivity, backgrounding and interruptions pause the timer. Completion removes the browser. A new session always requires a new intention and explicit start.")
                Text("After an unexpected app exit, only the last saved active duration is recovered. Sessions are grouped by their start day in your current time zone. This is not a measure of total device social media use.")
            }
        }.navigationTitle("Privacy & limitations")
    }
}

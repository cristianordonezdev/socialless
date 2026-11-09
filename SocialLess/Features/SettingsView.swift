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
                    LabeledContent("Distraction filters", value: "Unavailable")
                }
            }
            Section("Capabilities") {
                Text("Basic timed browsing only").font(.headline)
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
                Text("We do not read or extract social passwords, login cookies, messages, feed content or friend lists. Website session data is managed separately by WebKit and the website. A website may collect data under its own privacy policy.")
                Text("History and website data can be deleted separately in Settings. Device backups may include app data under your system backup settings.")
            }
            Section("Honest boundaries") {
                Text("All three website integrations are experimental and unverified on a physical iPhone. Login, messages or following views may be unavailable. Filtering and native app shielding are unavailable in this version.")
                Text("If a service rejects embedded browsing, SocialLess offers its offline demo. It does not bypass login restrictions or open another app automatically.")
            }
            Section("How time works") {
                Text("Only foreground active time counts, including page loading and error screens. Inactivity, backgrounding and interruptions pause the timer. Completion removes the browser. A new session always requires a new intention and explicit start.")
                Text("After an unexpected app exit, only the last saved active duration is recovered. Sessions are grouped by their start day in your current time zone. This is not a measure of total device social media use.")
            }
        }.navigationTitle("Privacy & limitations")
    }
}

import SwiftUI

struct OnboardingView: View {
    @Bindable var container: AppContainer
    @State private var step = 0
    @State private var minutes = 10
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("SocialLess", systemImage: "leaf").font(.headline)
                        Spacer()
                        Text("\(step + 1) / 3").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Image(systemName: step == 0 ? "leaf.circle" : step == 1 ? "hand.raised.circle" : "timer")
                        .font(.system(size: 72, weight: .ultraLight)).foregroundStyle(Theme.accent).accessibilityHidden(true)
                    Text(step == 0 ? "Social media,\non your terms." : step == 1 ? "A little structure.\nA clear boundary." : "Make room for\nwhat matters.")
                        .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    if step == 0 {
                        Text("Check in with intention. Leave with time for the rest of your day.").font(.title3).foregroundStyle(.secondary)
                        Card {
                            VStack(alignment: .leading, spacing: 18) {
                                Label("Choose why you’re here", systemImage: "scope")
                                Label("Set a small time limit", systemImage: "hourglass")
                                Label("Take a breath when it ends", systemImage: "sun.max")
                            }
                        }
                        Footnote(text: "Try the entire experience offline. No account or permissions needed.")
                    } else if step == 1 {
                        Card {
                            VStack(alignment: .leading, spacing: 18) {
                                Label("Your time stays on this device", systemImage: "lock.shield")
                                Text("SocialLess stores only optional session metadata. It never reads or records your social passwords, messages or feed.")
                                Divider()
                                Text("It cannot change native social apps or guarantee a friends-only feed. Website login and filtering depend on each service.")
                            }
                        }
                        Footnote(text: "Website login data is managed by WebKit and the service. You can clear it separately in Settings.")
                    } else {
                        Card {
                            VStack(alignment: .leading, spacing: 20) {
                                Picker("Default session", selection: $minutes) {
                                    ForEach(SessionConfiguration.allowedMinutes, id: \.self) { Text("\($0) minutes").tag($0) }
                                }.accessibilityIdentifier("onboarding.duration")
                                ForEach(SocialPlatform.allCases) { platform in
                                    Toggle(platform.title, isOn: Binding(get: { container.settings.enabledPlatforms.contains(platform) }, set: { enabled in
                                        if enabled { container.settings.enabledPlatforms.insert(platform) }
                                        else { container.settings.enabledPlatforms.remove(platform) }
                                    }))
                                }
                                Divider()
                                Toggle("Keep local session history", isOn: $container.settings.keepHistory)
                                Footnote(text: "Optional, stored only on this device. Includes clearly labeled demo sessions.")
                            }
                        }
                        Footnote(text: "We’ll start in offline demo mode. You can change each platform’s session length in Settings.")
                    }
                    PrimaryButton(title: step == 2 ? "Let’s begin" : "Continue") {
                        if step < 2 { step += 1 }
                        else { finish() }
                    }.accessibilityIdentifier("onboarding.continue")
                    if step > 0 { Button("Back") { step -= 1 }.frame(minHeight: 44) }
                }.padding(24).frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
            }.background(Theme.background)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Skip") { finish() }.accessibilityIdentifier("onboarding.skip") } }
        }
    }
    private func finish() {
        for platform in SocialPlatform.allCases { container.settings.defaultMinutes[platform] = minutes }
        container.settings.completedOnboarding = true
        container.saveSettings()
    }
}


import SwiftUI

struct DashboardView: View {
    @Bindable var container: AppContainer
    let open: (SocialPlatform) -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let today = UsageSummary(sessions: container.sessions).sessions(on: timeline.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Label("A little more present", systemImage: "leaf"); Spacer() }
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent)
                    Text("Check in.\nThen step away.").font(.largeTitle.bold())
                    Text("A moment for your people.\nMore room for your day.").font(.title3).foregroundStyle(.secondary)
                    Card {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(TimeLabel.duration(UsageSummary.total(today))).font(.title.bold()).monospacedDigit()
                                Text("Time today").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(today.count)").font(.title.bold())
                                Text("Sessions").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    HStack {
                        Text("Start intentional session").font(.headline)
                        Spacer()
                    }
                    ForEach(SocialPlatform.allCases.filter { container.settings.enabledPlatforms.contains($0) }) { platform in
                        Button { open(platform) } label: {
                            Card {
                                HStack(spacing: 16) {
                                    PlatformMark(platform: platform)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(platform.title).font(.headline).foregroundStyle(.primary)
                                        Text("\(container.settings.minutes(for: platform)) min · \(container.settings.defaultMode == .demo ? "Offline demo" : "Experimental web")")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").foregroundStyle(Theme.accent).accessibilityHidden(true)
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("platform.\(platform.rawValue)")
                            .accessibilityLabel("Start \(platform.title) session, \(container.settings.minutes(for: platform)) minutes, \(container.settings.defaultMode.title)")
                    }
                    if container.settings.enabledPlatforms.isEmpty {
                        ContentUnavailableView("Your quiet space", systemImage: "leaf", description: Text("Enable a platform in Settings whenever you want to check in."))
                    }
                    Label(container.settings.defaultMode == .demo ? "Offline demo is on" : "Website access is experimental", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    Footnote(text: "Time here measures SocialLess sessions, including demos. It does not include time in other apps.\(container.settings.keepHistory ? "" : " History is off; new sessions won’t appear in your totals.")")
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(Theme.background)
        }.navigationTitle("SocialLess").navigationBarTitleDisplayMode(.inline)
    }
}


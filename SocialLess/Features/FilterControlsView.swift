import SwiftUI

struct FilterControlsView: View {
    let platform: SocialPlatform
    let mode: BrowsingMode
    let ruleSet: FilterRuleSet?
    @Binding var preferences: FilterPreferences
    var health: FilterHealth?
    var counts: [String: Int] = [:]
    var canEnable = true
    var canRemember = false
    var checkPage: (() -> Void)?
    var canEnableRule: ((FilterRule) -> Bool)?
    var ruleCheckHealth: [String: FilterHealth] = [:]
    var checkRule: ((String) -> Void)?
    var followingStore: FollowingListStore?
    var followingFeed: FollowingFeedController?
    var storiesFilter: StoriesFilterController? = nil

    var body: some View {
        Form {
            Section {
                if mode == .demo {
                    Text("Navigation links only").font(.headline)
                    Text("This demo hides the Sample Discover and Sample Short videos links. The sample posts stay visible. Turn filters off to restore the links without reloading.")
                    Footnote(text: "Offline demo only. These rules do not filter real \(platform.title) content.")
                } else if ruleSet?.isAvailable == true {
                    Text("Experimental · Instagram navigation").font(.headline)
                    Footnote(text: "Choose Reels and Explore separately. These filters target navigation entries, not feed posts, stories, messages or search results. Content may still appear through other links.")
                } else {
                    Text("Real website · filters not active yet").font(.headline)
                    Footnote(text: "This is the real website inside SocialLess. Filtering is technically possible here, but rules for this service still need testing on an iPhone. The session timer works independently. Friends-only feeds are not guaranteed.")
                }
                if let health {
                    Label(health.title, systemImage: [.failed, .styleBlocked, .unsupportedLayout, .partial].contains(health) ? "exclamationmark.triangle" : "line.3.horizontal.decrease.circle")
                        .accessibilityIdentifier("filters.health")
                    if health == .noMatches {
                        Footnote(text: preferences.rememberedRuleSetVersion != nil && preferences.enabled
                                 ? "No compatible visible entry was found for your selected filters. Nothing is hidden. Your saved choices will be checked again as navigation loads. Feed posts are not covered."
                                 : "No visible compatible navigation entry was detected. Nothing is hidden. Return to the loaded feed and check again. Feed posts are not covered.")
                    } else if health == .unsupportedLayout {
                        Footnote(text: "Target links are present, but their navigation controls are not recognized. They have been left visible. This layout needs an updated rule.")
                    } else if health == .partial {
                        Footnote(text: "Some selected navigation filters could not apply. Compatible controls may be hidden while other entries remain visible. Turning filters off restores the hidden controls.")
                    } else if health == .styleBlocked {
                        Footnote(text: "The page’s styles prevented hiding the links. SocialLess restored its changes. Timed browsing is still available.")
                    } else if health == .failed {
                        Footnote(text: "Filtering could not continue. Turn it off, or reload the page to try again. Your session timer keeps running.")
                    }
                }
            }
            if let ruleSet, ruleSet.isAvailable {
                if ruleSet.requiresPageCheck, let reels = ruleSet.rules.first, !(canEnableRule?(reels) ?? canEnable) {
                    Section("Check this page first") {
                        Footnote(text: "Open the Instagram feed, then check for a compatible Reels link. Checking leaves the page unchanged. Filters start off unless you choose to remember them.")
                        Button(health == .checking ? "Checking…" : "Check Reels link") { checkPage?() }
                            .disabled(checkPage == nil || health == .checking || health == .loading || health == .paused)
                            .accessibilityIdentifier("filters.checkPage")
                    }
                }
                Section {
                    Toggle(mode == .demo ? "Enable demo filters" : "Enable navigation filters", isOn: Binding(
                        get: { canEnable && preferences.enabled }, set: { preferences.enabled = $0 }))
                        .disabled(!canEnable)
                        .accessibilityIdentifier("filters.enabled")
                    Footnote(text: "Turning this off restores links hidden by SocialLess without reloading. It does not reveal elements the page already hid.")
                }
                Section("Experimental navigation filters") {
                    ForEach(ruleSet.rules) { rule in
                        Toggle(rule.title, isOn: Binding(
                            get: { (canEnableRule?(rule) ?? true) && preferences.isEnabled(rule) },
                            set: {
                                preferences.ruleOverrides[rule.id] = $0
                                if rule.requiresIndividualCheck {
                                    var approved = preferences.approvedRuleIDs ?? []
                                    approved.insert(rule.id); preferences.approvedRuleIDs = approved
                                }
                            }))
                            .disabled(!canEnable || !preferences.enabled || !(canEnableRule?(rule) ?? true))
                            .accessibilityIdentifier("filters.rule.\(rule.id)")
                        if rule.requiresIndividualCheck, !(canEnableRule?(rule) ?? false) {
                            Button(ruleCheckHealth[rule.id] == .checking ? "Checking…" : "Check Explore link") { checkRule?(rule.id) }
                                .disabled(checkRule == nil || ruleCheckHealth[rule.id] == .checking || health == .loading || health == .paused)
                                .accessibilityIdentifier("filters.check.\(rule.id)")
                            Text("Explore starts off. Check its navigation entry, then choose whether to hide it. Checking leaves your active filters in place.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let state = ruleCheckHealth[rule.id] {
                            Text(state.title).font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("filters.checkStatus.\(rule.id)")
                        }
                        if let count = counts[rule.id], preferences.enabled || health == .ready {
                            Text(count == 1 ? "1 matching navigation link" : "\(count) matching navigation links")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if ruleSet.supportsRemembering {
                    Section("Future sessions") {
                        Toggle("Remember for Instagram", isOn: Binding(
                            get: { preferences.remembers(ruleSet) },
                            set: { remember in
                                var choice = preferences
                                if remember {
                                    for rule in ruleSet.rules where !(canEnableRule?(rule) ?? false) {
                                        choice.ruleOverrides[rule.id] = false
                                    }
                                }
                                choice.rememberedRuleSetVersion = remember ? ruleSet.ruleSetVersion : nil
                                preferences = choice
                            }))
                            .disabled(!preferences.remembers(ruleSet) && !canRemember)
                            .accessibilityIdentifier("filters.remember")
                        Footnote(text: "After filters are active, you can save your choices on this device. Future sessions check compatibility automatically before hiding links. Updated rules require a new check. Turning this off keeps this session’s choices and makes the next session start with filters off.")
                    }
                }
                Section {
                    LabeledContent("Rule version", value: ruleSet.ruleSetVersion)
                    Footnote(text: mode == .demo
                             ? "Demo preferences stay on this device and are separate for each platform. Filter health is temporary and contains no page content."
                             : "Navigation choices are saved if you choose to remember them. Imported account names are managed separately in Following list. Website sign-in stays separate. Counts and compatibility checks are temporary; no posts are saved.")
                }
            } else {
                Section {
                    LabeledContent("Distraction filters", value: "Unavailable")
                    if ruleSet == nil { Footnote(text: "The bundled rules could not be loaded. Timed browsing is still available.") }
                }
            }
            if let storiesFilter, mode == .website, platform == .instagram {
                Section("Experimental · Stories") {
                    Toggle("Filter stories", isOn: Binding(get: { storiesFilter.enabled }, set: { storiesFilter.setEnabled($0) }))
                        .accessibilityIdentifier("filters.storiesEnabled")
                    Text(storiesFilter.status).font(.footnote).accessibilityIdentifier("filters.storiesStatus")
                    Footnote(text: "Hides recognized sponsored stories in supported viewers. With an imported following list, identified accounts outside that list are hidden. Unrecognized stories stay visible and are not classified as sponsored. Starts off each session. No automatic skipping; turn off to restore. Unsupported layouts and unrecognized ads may remain visible.")
                }
            }
            if let followingStore, let followingFeed, mode == .website, platform == .instagram {
                Section("Experimental · Feed") {
                    NavigationLink("Manage following list") { FollowingListView(store: followingStore) }
                        .accessibilityIdentifier("filters.followingList")
                    Toggle("Only imported accounts", isOn: Binding(
                        get: { followingFeed.enabled }, set: { followingFeed.setEnabled($0) }))
                        .disabled(followingStore.list == nil)
                        .accessibilityIdentifier("filters.followingEnabled")
                    Text(followingFeed.status).font(.footnote).accessibilityIdentifier("filters.followingStatus")
                    if followingFeed.enabled {
                        Text("Hidden posts: \(followingFeed.hiddenCount) · Unrecognized: \(followingFeed.unknownCount)")
                            .font(.caption)
                        if followingFeed.unknownCount > 0 {
                            Footnote(text: "Unrecognized means the page layout did not reveal a reliable author or ad label. Those posts are hidden because their author cannot be confirmed in your list. This may hide posts from accounts you follow.")
                        }
                    }
                    Footnote(text: "Uses your imported list on the Instagram home feed only. Recognized sponsored posts are hidden too. Recognized cards are collapsed and cannot be interacted with while hidden. Unrecognized candidate posts are hidden too; unsupported layouts may still escape filtering. It does not fetch more posts or update the list automatically. Starts off each session; replacing or deleting the list turns it off. Reels and Explore navigation switches are separate.")
                }
            }

        }
        .navigationTitle(mode == .demo ? "Demo filters" : "Website filters")
        .navigationBarTitleDisplayMode(.inline)
    }
}

# SocialLess — Master Product & Engineering Specification

**Status:** Implementation-ready planning document  
**Document version:** 1.0  
**Prepared:** 2026-11-09  
**Primary audience:** Codex (implementation agent), solo iOS engineer  
**Initial release:** Personal-use iPhone prototype  
**Product language:** English (localization-ready)  
**Working name:** SocialLess

> **Codex instruction:** This document is the source of truth. Implement incrementally. Do not claim capabilities that iOS or social networks do not provide. Do not use private APIs, unofficial authenticated endpoints, credential extraction, or techniques designed to evade a platform's protections. Build a useful offline-first digital-wellbeing app even if all social websites reject embedded browsing.

---

## 0. Agent operating contract (READ FIRST)

You are the lead iOS engineer implementing SocialLess in the current repository. Your objective is to produce **compilable, testable, production-quality Swift code**, not just mockups, pseudocode, or a README.

1. Inspect the repository, toolchain, Xcode version, SDK, signing environment and existing files **before** making changes.
2. Record findings in `docs/IMPLEMENTATION_STATUS.md`, including what was built, what was run, what could not be tested, and why. Never report tests as passing unless you ran them.
3. Read this document completely, create a concrete task checklist in `docs/TASKS.md`, and implement in the sequence specified in §13.
4. Favor platform-native frameworks and simple architecture. Use SwiftUI, async/await, protocol-driven services, and injected dependencies. Avoid heavy frameworks unless justified.
5. Keep the project compilable at each milestone. Run a build and targeted tests whenever macOS/Xcode are available. If Xcode is unavailable (e.g., Windows/Linux), scaffold the source, add an XcodeGen project specification, perform static consistency checks, and explicitly mark native build/device validation as **pending**.
6. **No fabricated integrations:** Never assert that Instagram/Facebook/TikTok authentication, feed filtering, friends-only mode, direct messages, or Screen Time shielding works until independently validated on a real iPhone and the relevant service.
7. Hide unsupported features behind feature flags or display honest capability/availability labels. Make failure graceful.
8. Never write code that captures social network usernames, passwords, session cookies, authentication tokens, private messages, or personal content for storage/analytics.
9. Do not silently redirect to native social apps or bypass session limits. For external website/authentication links, require a deliberate, clearly explained user decision; document when filtering won't apply.
10. Keep the app usable with zero permissions and zero social account logins. Request permissions only at the moment they are needed.
11. Follow platform terms, privacy rules, accessibility guidelines, and App Store requirements. Personal-use prototype approval does not imply suitability for App Store distribution.
12. If a blocking external limitation occurs, implement a tested mock, fallback, or disable the affected module, continue other work, and document the blocker. Do not get stuck trying to bypass protection.
13. After each milestone, provide a short summary: files changed, key behavior, build/tests run, known limitations, and next milestone.

**Definition of implementation done:** Source files, project settings, assets, tests, documentation, and a reproducible build command exist. An unbuilt text-only plan is not a completed implementation.

---

## 1. Product purpose

### 1.1 Problem

Instagram, Facebook, and TikTok mix desired social interactions (friends' photos, updates, messages) with personalized recommendations, Reels/short videos, autoplay and unlimited feeds. A user intending to check friends may unintentionally spend a long time scrolling.

### 1.2 Mission

**Make social media intentional:** help users connect with friends without being pulled into algorithm-driven discovery and prolonged scrolling.

### 1.3 Product principles

- **Connection over consumption:** promote friend-oriented destinations when legitimately available.
- **Friction by design:** each browsing session starts with an intention and ends on a time limit.
- **Honest limitations:** never market imperfect filtering as guaranteed friends-only content.
- **User autonomy:** restrictions are opt-in, transparent, and can be disabled.
- **Privacy first:** on-device settings and aggregate usage only; no social data collection.
- **Accessible and calm:** no engagement-streak manipulation, shame, guilt, or deceptive dark patterns.
- **Reliability over hacks:** stop filtering gracefully if a website changes.

### 1.4 Who is it for?

Initially one adult iPhone owner who wants to check their friends' social activity while reducing compulsive use. Design for potential broader adult self-control use, but do not assume App Store approval.

### 1.5 Success measures (local and opt-in)

- Number of intentional sessions started/completed.
- SocialLess session minutes per day/week.
- Percentage of sessions ended when the limit was reached.
- Number of intentional exits before the timer ended.
- User-selected weekly time goal; simple trends compared to previous weeks.
- Filter health checks and available friend-oriented destinations, **not** counts of scraped posts.

Do **not** claim a reduction in all-device social usage unless authorized Screen Time data is available and measured correctly. Do not confuse in-app browsing time with total native-app usage.

---

## 2. Scope and non-goals

### 2.1 In-scope for V0.1 (core MVP, works offline)

- SwiftUI dashboard with the three services: Instagram, Facebook, TikTok.
- Optional onboarding explaining that friends-only filtering is best effort.
- Session intent prompt (e.g. "Check friends", "Reply to someone", "Quick update").
- Per-platform configurable in-app session budget (default 10 minutes, options 5/10/15/20/30).
- Visible countdown in the in-app browser; pause timing when app is backgrounded, with a documented monotonic elapsed-time policy.
- Terminal session-ended overlay that closes/disables web interaction until user intentionally returns to dashboard; no automatic extension.
- Local aggregate session history, basic daily/weekly analytics.
- Platform-specific secure `WKWebView` host with safe navigation policy and clearly visible back/close controls.
- Filtering framework with rules that can be enabled/disabled, health status, tests, and per-platform adaptation.
- Offline demo mode for screenshots and tests; graceful failure if websites are inaccessible.
- Privacy statement, accessibility support, no account registration, no backend.

### 2.2 In-scope for V0.2 (validated web experience)

- Manual QA of all 3 sites on a real iPhone, including authentication behavior where permitted.
- Per-service navigation presets: 'preferred friends/following entry' if verified in mobile web; fallback to home with informative label.
- Optional hide-discovery navigation and optionally redirect explicit navigation to disallowed discovery destinations **within the embedded web view only**, with clear explanation and reversibility.
- User-configurable rule toggles per service; versioned bundled selector rules.
- MutationObserver with throttling for modern single-page app navigation (no tight loops or broad DOM replacement).
- Kill switches for failing platform rules.
- Explicit capability matrix: Verified / Experimental / Unavailable.

### 2.3 In-scope for V0.3 (optional iOS Screen Time integration)

- Opt-in adult `FamilyControls` authorization.
- `FamilyActivityPicker` to select native social apps without hardcoded bundle IDs or inspecting token details.
- Optional `ManagedSettings` shielding of user-selected native apps on a schedule.
- Optional `DeviceActivity` monitoring thresholds with a dedicated app extension and necessary App Group storage.
- Clearly explain that shielding blocks the **entire native app** (including messages), not just Reels or recommendations.
- Settings to turn shielding off, revoke authorization, recover from entitlement denial.
- Require actual capabilities, entitlements, code signing, and on-device tests before enabling.

### 2.4 Future versions (not MVP)

- V0.4: optional Safari Web Extension/content-blocking path if embedded WebViews are not dependable AND permission/terms review permits it.
- V0.5: accessibility polish, localization, export/delete local data, enhanced user research, refined rules.
- V1.0: only after legal/terms review, service compatibility tests, user testing, and distribution entitlement approval. If permissions are insufficient, ship only the compliant native wellness features.

### 2.5 Explicit non-goals

- No unified social feed scraped from Instagram/Facebook/TikTok.
- No reverse engineering of private GraphQL/mobile APIs or unauthorized scraping.
- No automatic identification of 'real friends' through user social graphs.
- No injection into or modification of the **native** Instagram/Facebook/TikTok applications.
- No bypass of login challenges, CAPTCHAs, browser checks, rate limits, or anti-bot measures.
- No unauthorized API proxy, MITM interception, VPN packet inspection, certificate manipulation, or sideloaded modifications.
- No promises to remove *all* suggested posts, ads, Reels, or For You recommendations.
- No guaranteed access to DMs or Stories through WebKit.
- No user social-account credentials, messages, or feed content stored by SocialLess.
- No claims of foolproof adult self-locking: individual-authorized restrictions may be revoked or bypassed.
- No cloud sync, social backend, third-party analytics SDK, subscriptions, or in-app payments for V0.x.

---

## 3. Platform feasibility and truth in UI

### 3.1 Shared constraints

- `WKWebView` can host a website and insert content scripts **in the app's own web view**. It cannot modify other apps.
- A CSS/JS selector can hide observed UI elements; it cannot tell reliably whether every feed item is from a friend.
- The platforms control their login policies, websites, navigation and available feature sets. A working user-agent or login flow must **never** be assumed.
- SocialLess must not present a social network's content as if officially supported or endorsed.
- Respect terms and App Review Guideline 5.2.2; distribution may require specific permission from third-party providers.

### 3.2 Instagram

- Official Instagram includes Following and Favorites feed choices in its app; this does not prove the equivalent destination or deep link works in mobile WebKit.
- Preferred MVP: verified web-supported feed choice if available; otherwise 'Open Instagram' without claiming friends-only.
- Candidate experimental UI filtering: hide navigation links to `/explore/` and `/reels/` if present. Verify exact routes and selectors on real devices; paths are **hypotheses**, not guarantees.
- Friends-only cannot be guaranteed. Following may include creators and public accounts; Favorites must be curated by the user on Instagram.

### 3.3 Facebook

- Meta introduced a dedicated Friends tab with friend content and no recommendations, initially in certain regions; mobile web availability and supported navigation need real-device verification.
- Prefer Facebook's own Friends view if the user has access; no fabricated friends-only URL.
- Candidate experimental filter: hide verified Watch/Reels discovery affordances. Never block friend posts merely because they contain video.

### 3.4 TikTok

- TikTok's Friends tab can include followed accounts and suggested accounts in some regions. Even native Friends is **not necessarily strictly friends-only**.
- TikTok web may not offer the same tabs/DM functionality as native. Assess before building special flows.
- Prefer a validated Following/Friends web destination if possible; otherwise show a limitation and provide short, timed browsing only.
- Do not claim For You is completely removed based solely on hiding one navigation link.

### 3.5 Capability matrix model

Each platform/feature must expose an `AvailabilityStatus`:

```swift
enum AvailabilityStatus: String, Codable {
    case verified       // Confirmed by a documented manual test on the current site
    case experimental   // Implemented but can fail as sites change
    case unavailable    // Cannot currently be supported
}
```

Store `lastVerifiedAt`, `platform`, `appVersion`, `testDeviceOS`, `notes` in **developer QA fixtures**, not automatically scraped user data. UI text must say, for example, "Experimental: Hide Reels links" rather than "Reels eliminated".

---

## 4. Recommended technical stack

| Layer | Selection | Reason |
|---|---|---|
| Platform | iPhone, iOS 17+ baseline | Modern SwiftUI; verify OS compatibility with installed SDK |
| Language | Swift 5.9+ / installed current Swift toolchain | Native Apple ecosystem |
| UI | SwiftUI, SF Symbols | Fast, accessible native UI |
| Architecture | Lightweight MVVM + services via protocols | Testability and maintainability |
| Browser | WebKit / `WKWebView` | Supported embedded browser API |
| Browser rules | `WKUserScript` + `WKContentWorld` where appropriate | Sandboxed in-WebView filtering |
| Network content rules | `WKContentRuleListStore` only for justified URL-based resource restrictions | Optional; not a DOM friends detector |
| Persistence | SwiftData for session records; `UserDefaults` for trivial settings | Local-first; simple to ship |
| Clock & sessions | `ContinuousClock`/time provider abstraction + lifecycle handling | Testable time accounting |
| Concurrency | Swift structured concurrency, `@MainActor` for UI state | Avoid race conditions |
| Testing | XCTest + XCUITest + static HTML fixtures | Deterministic functional tests |
| Metrics | Local aggregates, no remote telemetry | Privacy |
| Screen Time (V0.3) | `FamilyControls`, `ManagedSettings`, `DeviceActivity` | Native opt-in shielding/thresholds |
| Project generation | Native `.xcodeproj` or XcodeGen `project.yml` | Repeatable local setup |
| CI | GitHub Actions on macOS runner, if accessible | Build + tests, optional |
| External dependencies | None initially | Fewer maintenance/privacy risks |

### Build environment

- A Mac with recent compatible Xcode is required to compile/sign/run the iPhone app. An Apple silicon Mac is supported, subject to installed Xcode compatibility.
- Use iPhone Simulator for unit and initial UI tests; validate Family Controls and social logins **on physical iPhone**.
- App can be built in a source repository from any machine, but iOS final builds/signing require macOS/Xcode.
- Never promise Screen Time production permissions without entitlement approval.

---

## 5. Proposed repository layout

```text
SocialLess/
├── README.md
├── SOCIALLESS_CODEX_MASTER_SPEC.md
├── AGENTS.md
├── .gitignore
├── project.yml                          # XcodeGen spec if used
├── SocialLess.xcodeproj/                 # Generated or maintained project
├── SocialLess/
│   ├── App/
│   │   ├── SocialLessApp.swift
│   │   ├── AppContainer.swift           # Dependency graph
│   │   └── AppRouter.swift
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Components/
│   │   └── AccessibilityIdentifiers.swift
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── SocialPlatform.swift
│   │   │   ├── SessionIntent.swift
│   │   │   ├── BrowsingSession.swift
│   │   │   ├── PlatformCapability.swift
│   │   │   └── FilterPreferences.swift
│   │   ├── Services/
│   │   │   ├── SessionClocking.swift
│   │   │   ├── SessionRepository.swift
│   │   │   ├── SettingsRepository.swift
│   │   │   └── PlatformRulesProviding.swift
│   │   └── UseCases/
│   │       ├── StartSession.swift
│   │       ├── FinishSession.swift
│   │       └── DailyUsageSummary.swift
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── Dashboard/
│   │   ├── IntentionPicker/
│   │   ├── Browser/
│   │   │   ├── BrowserView.swift
│   │   │   ├── BrowserViewModel.swift
│   │   │   ├── SocialWebView.swift
│   │   │   ├── WebNavigationPolicy.swift
│   │   │   └── BrowserErrorView.swift
│   │   ├── SessionComplete/
│   │   ├── Insights/
│   │   ├── Settings/
│   │   └── ScreenTime/                  # V0.3, gated
│   ├── Infrastructure/
│   │   ├── Persistence/
│   │   │   ├── SwiftDataSessionRepository.swift
│   │   │   └── UserDefaultsSettingsRepository.swift
│   │   ├── Time/
│   │   │   ├── MonotonicSessionClock.swift
│   │   │   └── TestClock.swift
│   │   ├── Web/
│   │   │   ├── FilterScriptFactory.swift
│   │   │   ├── FilterRuleRegistry.swift
│   │   │   ├── BrowserSecurityPolicy.swift
│   │   │   └── BrowserSessionController.swift
│   │   └── ScreenTime/                  # V0.3, gated
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Rules/
│       │   ├── instagram.json
│       │   ├── facebook.json
│       │   └── tiktok.json
│       └── Demo/
│           ├── instagram_fixture.html
│           ├── facebook_fixture.html
│           └── tiktok_fixture.html
├── SocialLessTests/
│   ├── SessionTimerTests.swift
│   ├── SessionRepositoryTests.swift
│   ├── PlatformNavigationTests.swift
│   ├── FilterScriptFactoryTests.swift
│   └── UsageSummaryTests.swift
├── SocialLessUITests/
│   ├── OnboardingUITests.swift
│   ├── SessionFlowUITests.swift
│   └── FilterControlsUITests.swift
├── SocialLessDeviceActivityMonitor/       # V0.3 extension, only once authorized
│   └── DeviceActivityMonitorExtension.swift
└── docs/
    ├── TASKS.md
    ├── IMPLEMENTATION_STATUS.md
    ├── ARCHITECTURE.md
    ├── PLATFORM_COMPATIBILITY.md
    ├── MANUAL_QA.md
    ├── PRIVACY_AND_TERMS.md
    ├── DECISIONS.md
    └── RELEASE_CHECKLIST.md
```

**Note:** The project must not reference V0.3 extension targets before they exist. The structure is a roadmap, not a requirement to generate empty placeholder classes everywhere.

---

## 6. Screens and UX flows

### 6.1 Onboarding

1. **Welcome:** "Social media, on your terms."
2. **What SocialLess does:** intentional sessions, limits, experimental distraction reduction.
3. **What it cannot do:** modify native apps or guarantee friends-only feeds.
4. **Privacy:** SocialLess does not ask for or store social account credentials.
5. **Personalization:** default session length and enabled platforms.
6. **Finish:** go to dashboard; don't require Screen Time permissions.

### 6.2 Dashboard

- Calm dark/light adaptive UI; high contrast and Dynamic Type.
- Platform cards for Instagram, Facebook, TikTok with availability indicator.
- Total SocialLess minutes today, remaining budget, sessions today.
- Primary CTA: **Start intentional session**.
- Secondary navigation: Insights, Settings, About/Privacy.
- Clear disclosure: "Time here measures SocialLess browsing, not all social media use."

### 6.3 Start a session

1. Tap platform.
2. Choose intent: Check friends / Reply to messages / Other.
3. Choose 5/10/15/20/30 minutes (default from settings).
4. Present current filtering capability status and whether login may fail.
5. Tap **Start**; create active session and enter WebView.

### 6.4 Active session

- Persistent top toolbar: platform, session intent, remaining time, close.
- `WKWebView` occupies remaining content area.
- Browsing timer counts only while the app/scene is active and the session is running. Define behavior for interruptions; no hidden unbounded timer.
- Show a non-modal warning at 60 seconds remaining.
- Show simple error/retry state for unsupported or failed pages.
- Provide a filter menu (when supported) with experimental toggles.
- Never automatically trigger infinite-scroll gestures, clicks, likes, follows or messages.

### 6.5 Session expiration

- Immediately stop user interaction with the web view, hide or remove it, and save session.
- Show: "Time's up. You checked in — now move on."
- Show actual active time, platform, intention.
- Buttons: **Done** (dashboard) and **Start a new intentional session** (explicit fresh setup, subject to configured daily budget).
- No automatic additional time, no dark pattern to keep using.

### 6.6 Insights

- Today and last 7 days: total minutes and session counts by platform.
- Calm, neutral trend charts. No gamification/shaming.
- Clearly label that totals exclude native app time unless optional authorized integration is implemented.

### 6.7 Settings

- Default session length per platform.
- Optional overall daily in-app budget (Phase V0.2; enforce when enabled).
- Platform filter switches, each labeled Verified/Experimental/Unavailable.
- Ability to disable filters if websites break.
- Export or delete local history (later phase); basic reset in V0.1.
- Screen Time integration (V0.3 only), permission status and a large **Disable restrictions** control.
- Privacy, limitations, attribution, app version.

---

## 7. Core domain models and state

Use concise, `Codable` / `Identifiable` types where appropriate.

```swift
enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram, facebook, tiktok
    var id: String { rawValue }
}

enum SessionIntent: String, Codable, CaseIterable {
    case checkFriends, replyToMessages, other
}

enum SessionEndReason: String, Codable {
    case userEnded, timeLimitReached, navigationFailure, appTerminated
}

struct SessionSummary: Identifiable, Codable {
    let id: UUID
    let platform: SocialPlatform
    let intent: SessionIntent
    let startedAt: Date
    let endedAt: Date
    let activeDurationSeconds: TimeInterval
    let endReason: SessionEndReason
}

struct SessionSettings: Codable {
    var defaultDurationSeconds: TimeInterval = 600
    var filtersEnabled = true
}
```

Session state machine:

```text
idle -> configured -> active -> warning -> completed
                    |       |                ^
                    |       +-> completed ----|
                    +-> canceled (no session persisted)
active -> paused (scene inactive) -> active
active -> interrupted -> completed (if cannot safely resume)
```

### Timer invariants

- Never depend exclusively on a 1-second `Timer` firing precisely or on wall-clock `Date` differences while active.
- Use a monotonic elapsed-time source for active segments; accumulate segments when scene becomes inactive.
- Refresh UI on a timer/timeline, but enforce expiration based on accumulated elapsed time.
- On cold launch after process termination, close stale sessions safely and mark `appTerminated`; do not count unmeasured background time as browsing.
- Persist completed sessions once (idempotently); protect against double save.
- Ensure budget logic handles timezone/date boundaries; avoid negative durations and counters.
- Document that system Screen Time tracking and app-local session tracking are independent.

---

## 8. Web filtering subsystem

### 8.1 Design goals

- Rule system is **deterministic**, **reversible**, **platform-scoped**, and **tested against local HTML fixtures**.
- Treat website UI selectors as unstable; never hardcode a claim that they will remain valid.
- Avoid parsing user content or building a feed recommender.
- Failure should not break login, navigation, feed rendering, or accessibility.

### 8.2 Rule file format (bundled JSON)

```json
{
  "platform": "instagram",
  "schemaVersion": 1,
  "ruleSetVersion": "0.1.0",
  "availability": "experimental",
  "rules": [
    {
      "id": "hide-explore-navigation",
      "enabledByDefault": true,
      "kind": "hideAnchorByPath",
      "pathPrefix": "/explore/"
    },
    {
      "id": "hide-reels-navigation",
      "enabledByDefault": true,
      "kind": "hideAnchorByPath",
      "pathPrefix": "/reels/"
    }
  ]
}
```

Example is a **candidate**, not verification of current Instagram HTML. Validate paths using current public page markup or user-permitted on-device tests before enabling defaults. Equivalent Facebook/TikTok JSON should contain **empty rule arrays** until separately validated; do not guess selectors or destinations.

### 8.3 Filter engine responsibilities

1. Decode/validate bundled JSON; reject malformed/unknown rule types safely.
2. For supported hostname and exact route prefix, operate only on matching DOM navigation links.
3. Inject `WKUserScript` only for the selected platform host. In a universal script, check `window.location.hostname` against the known service origin.
4. Use `MutationObserver` on a small relevant subtree or throttle at ~200-500ms; avoid recursive mutation loops.
5. Use safe `Element.hidden` or a scoped CSS class; retain an 'off' setting to restore visibility. Do not indiscriminately delete DOM or intercept authentication forms.
6. Disconnect observer and remove injected state when navigation/session ends as feasible.
7. Maintain per-rule diagnostics in memory (e.g., matched element count). Do **not** log text content, URLs with query params, cookies, or credentials.
8. Keep disallowed destinations optional and user-visible; route blocking should be based on parsed URL host/path, not string substring on arbitrary raw URLs.
9. Never block essential login/consent/account recovery flows. For cross-domain auth, present a clear fallback instead of insecurely opening broad navigation.
10. For unsupported sites, disable injection and display 'Basic timed browsing only'.

### 8.4 Web security

- Load only HTTPS for primary platforms; reject `http:`, `file:`, `javascript:`, unexpected custom schemes by default.
- Define strict allowlisted base domains (`instagram.com`, `facebook.com`, `tiktok.com`) using exact host or `.`-delimited suffix matching, never `contains`.
- Social login/CDN/support redirects must be analyzed case-by-case and documented; do not globally allow arbitrary external origins.
- Treat new windows (`target=_blank`) with explicit handling; never silently escape timer rules to Safari/native apps.
- `WKWebView` uses an ordinary persistent website data store if account login is supported; do not use JavaScript to read secrets or cookies.
- Add **Clear website data** control with clear scope and user confirmation.
- Disable developer debugging and verbose URL logging in release builds.
- Disable file access/content interaction that isn't needed. Do not implement arbitrary download or media extraction.
- Use external Safari for blocked/unsupported authentication **only after user confirmation**; note that SocialLess cannot filter Safari or native apps by default.
- Filter scripts are local bundled assets; no remote execution, user-authored arbitrary JS, or remotely fetched rule scripts in MVP.

### 8.5 Compatibility fallback order

1. Validated preferred web friends/following destination.
2. Validated standard web platform home + safe experimental filters.
3. Standard platform home with filtering disabled (timed browsing only).
4. If embedded login is disallowed: explain limitation; provide alternative **intentional launcher** with Screen Time controls where available, clearly stating SocialLess cannot filter the external native app.
5. If the service cannot be used compliantly, show **Unavailable** and preserve dashboard/timer/insights functionality.

---

## 9. Screen Time optional architecture (V0.3)

**Do not implement until V0.1 and V0.2 are stable.** This feature requires real-device entitlement validation.

### Public API mapping

- `FamilyControls`: adult self-authorization `AuthorizationCenter.shared.requestAuthorization(for: .individual)`; user-driven `FamilyActivityPicker`.
- `ManagedSettings`: shielding selected application tokens; no direct modification of native screens.
- `DeviceActivity`: monitor events/thresholds in an extension; keep monitored ranges distinct from in-app timer semantics.
- App Groups: share only strictly necessary configuration/state with extension; verify correct group and signed entitlements.

### Screen Time UX and control policy

- Explain exactly which apps will be shielded and at what times.
- Obtain opt-in permission; gracefully handle denied/revoked authorization or missing entitlements.
- Never automatically apply shields to unknown apps or all categories without review.
- Provide one-tap **Disable restrictions** where authorized and supported.
- Do not claim restrictions are tamper-proof; users with individual authorization retain agency.
- No claims of bypass-proof blocking or selective removal of Reels inside native apps.
- Test extension behavior when app is killed, device restarts, timezone changes, daylight saving transitions, and authorization is revoked.

### Extension boundaries

- Do not add extension target until build configuration and provisioning are confirmed.
- Keep extensions lean; they can be invoked independently of the main app.
- Avoid assuming extensions can navigate UI, read browser sessions, or retrieve friends' posts.

---

## 10. Privacy, security, legal, and ethics

### Privacy requirements

- Local-only session metadata: platform, chosen intent, timestamps, elapsed active duration, completion reason.
- No user account in SocialLess.
- No server backend in MVP.
- No advertising IDs, cross-app tracking, analytics SDK, contacts, Photos, microphone, camera, or notification permission unless a separately justified feature needs them.
- Do not collect social profile identifiers, feed/media content, message text, login details, cookies, or friend lists.
- Avoid instrumentation of `WKWebView` content beyond filter diagnostics; do not persist a browsing history.
- Clear user data and web login data separately, with confirmation.
- Explain website logins remain between the user and the social service; embedded website behavior is controlled by that service.
- Use OS-provided storage protection and avoid logging secrets.

### Compliance gates

**Personal prototype:** Validate against social platform terms before using third-party website content in an embedded client.

**App Store distribution:** Seek legal/terms review, relevant third-party permissions where required, App Review Guideline 4.2 minimum functionality compliance, Guideline 5.2.2 third-party site/service permissions, and Screen Time distribution entitlements (including extensions) if used. App Store acceptance cannot be guaranteed.

**No evasion:** If a provider blocks a web view, do not spoof around protections, extract session material, or substitute unauthorized internal APIs.

---

## 11. Accessibility and visual design

### Visual direction

- Minimal, distraction-free, calm. Neutral background, restrained accent color.
- System typography; large countdown; native cards; consistent spacing.
- Support system Light/Dark modes, Dynamic Type, landscape, and small iPhones.
- No unnecessary animations or bright reward confetti.

### Accessibility requirements

- VoiceOver labels on buttons/platform cards/timer.
- Dynamic Type sizing and readable chart alternatives.
- High color contrast; never communicate state by color alone.
- 44pt minimum targets where possible.
- Reduce Motion and accessibility notification support.
- Accessibility IDs for deterministic UI tests.
- Error text with actionable next steps.

---

## 12. Testing and acceptance criteria

### 12.1 Unit tests

- Creating/canceling/ending sessions.
- Active-time accounting across foreground/background cycles.
- Expiration and 60s warnings at exact boundary values.
- Clock irregularities (wall-clock changes do not change active durations).
- Once-only session persistence and last session recovery.
- Usage summaries grouped by calendar day and platform.
- `SocialPlatform` host validation: `instagram.com`, `www.instagram.com` accepted; `evilinstagram.com`, `instagram.com.evil.test`, `http://instagram.com`, `javascript:` rejected.
- Rule JSON decoding, invalid types, path-prefix normalization, platform scoping.
- Zero/negative/bad durations rejected.

### 12.2 Filter fixtures (no social login required)

- Local HTML fixtures simulating known navigation links.
- Script hides only intended anchors and does not remove content unrelated to matching links.
- Script can be switched off and original elements restored.
- SPA simulated navigation / injected elements handled without excessive mutation work.
- No script runs on foreign domains.
- Broken/missing selector -> no crash, log only non-sensitive diagnostics.

### 12.3 UI tests

- First launch -> onboarding -> dashboard.
- Choose platform -> intent -> time limit -> timer view (use local test page).
- Session expiration -> browser disabled -> completion summary.
- Background/resume test with injected clock or deterministic lifecycle simulation.
- Settings toggles persist across launch.
- No permissions/login required to use demo mode.

### 12.4 Real iPhone QA matrix

Test iOS versions supported by the build (at least one modern device/OS), with three platforms:

| Case | Instagram | Facebook | TikTok |
|---|---|---|---|
| Website opens in WKWebView | Test | Test | Test |
| Sign-in is permitted and stable | Test | Test | Test |
| Feed can be viewed | Test | Test | Test |
| Friend/following destination exists on web | Test | Test | Test |
| Experimental rules match current DOM | Test | Test | Test |
| Navigation and deep links stay in browser | Test | Test | Test |
| Timed session ends reliably | Test | Test | Test |
| Platform changes / unavailable state handled | Test | Test | Test |

Fill `docs/PLATFORM_COMPATIBILITY.md` with **actual** observations and date/device. Do not pre-mark any item as passed.

### 12.5 Release gate criteria for V0.1

- [ ] App builds for iOS Simulator using project configuration.
- [ ] All offline unit tests and UI tests pass (or documented environment limitation).
- [ ] Onboarding, dashboard, session intent, browser shell, timer, history, settings work.
- [ ] User can use app fully in demo mode without social account login.
- [ ] No hidden background timers, unexpected navigation, or secret logging.
- [ ] Experimental filtering is disabled until rules are validated or clearly labelled experimental.
- [ ] Privacy and limitations documented in app.
- [ ] Accessibility smoke tests performed.

### 12.6 V0.2 additional gate

- [ ] All three websites assessed on physical iPhone.
- [ ] If one website disallows embedding/login, fallback path works and is honest.
- [ ] Platform rule fixture tests pass.
- [ ] No guarantee of friends-only unless a provider-authorized feature supports it and the claim is accurate.

### 12.7 V0.3 additional gate

- [ ] Entitlements and provisioning available.
- [ ] User consent and denied/revoked flows tested.
- [ ] Only selected native apps shielded.
- [ ] Disable restrictions reliably removes app-owned shields.
- [ ] Extension tested on device, including monitoring schedules.

---

## 13. Ordered Codex work plan

Implement in these vertical slices. **Do not jump to Screen Time before the browser/session foundation works.**

### Phase 0 — Repository bootstrap

**Tasks**
1. Audit repository, build environment, signing availability.
2. Create Xcode project/XcodeGen spec, assets, targets, folder structure only as needed.
3. Add `README.md`, `AGENTS.md`, `docs/TASKS.md`, `docs/DECISIONS.md`, `docs/IMPLEMENTATION_STATUS.md`.
4. Establish test target and a trivial launching app.

**Acceptance:** App starts in Simulator where possible; build command documented.

### Phase 1 — Offline functional experience

**Tasks**
1. Define domain types, repositories, dependency injection.
2. Implement onboarding, dashboard, intent picker, session setup, countdown and completion.
3. Add mock browser page as bundled local HTML for deterministic testing.
4. Persist session history; implement insights and settings.
5. Implement lifecycle-safe timer and tests.

**Acceptance:** End-to-end demo session works without internet, website login, or permission prompts.

### Phase 2 — Restricted WebKit host

**Tasks**
1. Implement `UIViewRepresentable` hosting a single `WKWebView` per browser session.
2. Navigation delegate with strict HTTPS and host validation; explicitly handle redirects/popups.
3. Clear website data function.
4. Browser errors, progress, closing behavior and session expiration handling.
5. Tests for navigation policy and UI shell.

**Acceptance:** Safe website browsing shell; blocked/unsupported navigation is clear and doesn't open unfiltered apps invisibly.

### Phase 3 — Experimental filters and capabilities

**Tasks**
1. JSON rules schema, parser, validation and script factory.
2. Local HTML fixture tests.
3. Add experimental filtering support for each platform only where verified.
4. Create capability UI and manual compatibility checklist.
5. Document unsupported content and test results.

**Acceptance:** Rules do not break login or other sites, can be toggled, and failures are surfaced.

### Phase 4 — Hardening

**Tasks**
1. Accessibility pass, data privacy pass, lifecycle/clock hardening.
2. Build/review on real device, manually inspect all three web services.
3. Add Settings reset, privacy view, useful non-sensitive diagnostics.
4. Create release checklist and user-friendly first-run demo.

**Acceptance:** Stable personal MVP with documented limitations.

### Phase 5 — Optional Screen Time

**Tasks**
1. Verify personal/team entitlement and on-device authorization path.
2. Add FamilyActivityPicker, secure token selection storage, shielding services.
3. Add DeviceActivity monitor extension only if required by chosen feature.
4. Verify revocation/disable behavior and privacy.
5. Mark feature unavailable if capability isn't granted.

**Acceptance:** Opt-in, reversible native-app shielding works on a real authorized device; no claim of selective in-app filtering.

---

## 14. Suggested implementation contracts

### 14.1 Core protocols

```swift
protocol SessionRepository {
    func save(_ session: SessionSummary) async throws
    func loadSessions() async throws -> [SessionSummary]
    func deleteAll() async throws
}

protocol SessionClocking {
    func start()
    func pause()
    func resume()
    func elapsedSeconds() -> TimeInterval
    func stop() -> TimeInterval
}

protocol PlatformRulesProviding {
    func rules(for platform: SocialPlatform) throws -> PlatformRuleSet
}
```

Codex may adapt these signatures for Swift actor-isolation or protocol design, but **must** keep the logic unit testable through injected fakes.

### 14.2 Navigation policy pseudocode

```text
When a navigation action is requested:
  parse URL
  if non-HTTPS -> cancel + explain
  if first-party matching the selected root domain -> allow
  if known redirect/support/auth origin -> only allow after explicit documented review
  else -> cancel + present user choice

When session expires:
  dismiss or cover WKWebView immediately
  stop future navigation and gestures
  persist exactly one SessionSummary
  navigate to SessionComplete
```

Caution: first-party host-only restriction will break some legitimate OAuth/help flows; do not paper over this with `allow all`. Instead document exact redirect needs and decide whether the service is compatible.

### 14.3 Example Family Controls code (V0.3 only)

```swift
import FamilyControls

func requestScreenTimeAuthorization() async throws {
    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
}
```

Only compile this in a properly entitled target. Authorization is distinct from permission to distribute; do not call this at cold launch in V0.1. Add `FamilyActivityPicker` and app tokens later rather than hardcoding Instagram/Facebook/TikTok identifiers.

---

## 15. Design decisions to record (ADRs)

Create `docs/DECISIONS.md` with short Architectural Decision Records:

- ADR-001: SwiftUI + native WebKit vs React Native/Flutter.
- ADR-002: No backend; privacy-first local storage.
- ADR-003: Why friends-only cannot be guaranteed for social third parties.
- ADR-004: Local session timer separate from Screen Time.
- ADR-005: Rule-based UI filtering rather than network interception/scraping.
- ADR-006: Fallback strategy when WebKit authentication fails.
- ADR-007: Optional Screen Time shielding only after entitlement approval.

---

## 16. Risks and mitigation

| Risk | Severity | Mitigation |
|---|---|---|
| Embedded login is blocked by a social site | High | Disable that browser integration; provide timed launcher/fallback, no bypass |
| HTML/selectors change | High | Versioned rules, manual validation, kill switch, fixture tests |
| Friends-only cannot be guaranteed | High | Accurate labels; use official feed choices where present |
| App Store permission to embed third-party service absent | High | Do not distribute the embedded browser; use native wellness-only product if compliant |
| Screen Time entitlement unavailable | Medium/High | Feature flag off, focus on session browser MVP |
| Timer inaccurate in background | Medium | Monotonic active segments + scene lifecycle tests |
| User escapes restriction to native social app | Medium | Disclose; optional authorized app shielding in V0.3 |
| Excessive DOM mutation hurts battery | Medium | Throttling, narrow selectors, script cancellation, performance tests |
| Social browsing exposes sensitive info | High | No extraction, logging, proxying, or analytics of private content |
| Third-party domains required for auth | Medium | Explicit reviewed allowlist, clear error/fallback |

---

## 17. Proposed version roadmap

| Version | Label | Main deliverable | Exit criteria |
|---|---|---|---|
| 0.1.0 | Functional foundation | Onboarding, dashboard, timer, session history, demo web flow | Offline demo fully tested |
| 0.2.0 | Web feasibility | Real WebKit host, manual platform compatibility, experimental rules | Verified device matrix and fallbacks |
| 0.3.0 | Optional native guardrails | Adult Screen Time permission, app selection, optional shields | Device entitlement/test success |
| 0.4.0 | Alternative integration | Investigate Safari extension if webview is insufficient | Compliant architecture decision |
| 0.5.0 | Polish | Accessibility, export/delete, localization, UX refinement | QA and privacy pass |
| 1.0.0 | Candidate public release | Only legally/technically supported modules | Terms, third-party permissions, entitlement, App Review readiness |

If embedded browsing is not viable for all three platforms, keep the supported platforms and ship a strong **digital-wellbeing app**, rather than inventing fake friends-only feeds.

---

## 18. Codex deliverables

At the end of the implementation run, output:

1. Actual Xcode project or XcodeGen definition and compilable Swift source.
2. Tests and test fixtures.
3. `README.md` with requirements, commands, device setup and limitations.
4. `AGENTS.md` with future coding-agent conventions.
5. `docs/TASKS.md` with completed/remaining boxes.
6. `docs/IMPLEMENTATION_STATUS.md` listing executed commands/results, environment blockers, and known defects.
7. `docs/PLATFORM_COMPATIBILITY.md` with explicit Tested / Untested entries for each service.
8. `docs/PRIVACY_AND_TERMS.md` and `docs/RELEASE_CHECKLIST.md`.
9. Small final summary with how to run, which scenarios are real, which are demos, and exactly what must be tested on an iPhone.

### Preferred build commands (adapt to actual project)

```bash
# XcodeGen (only if project.yml is used and xcodegen is installed)
xcodegen generate

# Discover schemes/devices
xcodebuild -list -project SocialLess.xcodeproj
xcrun simctl list devices available

# Build for simulator (replace scheme/destination as needed)
xcodebuild -project SocialLess.xcodeproj \
  -scheme SocialLess \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# Tests on an actually installed simulator (substitute its name/OS)
xcodebuild -project SocialLess.xcodeproj \
  -scheme SocialLess \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

Do not assume the example simulator model exists; discover and select an installed destination.

---

## 19. Sources and official docs to consult before coding sensitive modules

- Apple's App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/ (especially §§ 2.5.1, 4.2, 5.2.2)
- Apple's WebKit documentation: https://developer.apple.com/documentation/webkit
- Apple's content rule list APIs: https://developer.apple.com/documentation/webkit/wkcontentruleliststore
- Apple's Family Controls: https://developer.apple.com/documentation/familycontrols
- Apple's authorization API: https://developer.apple.com/documentation/familycontrols/authorizationcenter
- Apple's distribution entitlement requirements: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- Apple's DeviceActivity: https://developer.apple.com/documentation/deviceactivity
- Meta's Instagram Following/Favorites introduction: https://about.fb.com/news/2022/03/two-new-ways-to-control-your-instagram-feed/
- Meta's Facebook Friends tab introduction: https://about.fb.com/news/2025/03/bringing-magic-of-friends-back-to-facebook/
- TikTok Friends tab support: https://support.tiktok.com/en/using-tiktok/exploring-videos/friends-tab

**Agent rule:** Check these docs against the current installed toolchain before implementing APIs. Product behavior, regional rollout, terms, and Apple requirements can change.

---

## 20. Immediate first Codex instruction

**Start coding now.** First audit the repository/environment, then complete **Phase 0 and Phase 1** in this run, including a working demo and real source files. If native compilation is possible, build and test. If no macOS/Xcode environment is available, produce a consistent XcodeGen project and make native verification explicitly pending. Do not attempt unauthorized social APIs or label experimental filter behavior as verified. When Phase 1 is complete, proceed to Phase 2 if time/environment allow, preserving build stability and a completed status checklist throughout.

**Priorities when trade-offs arise:** privacy/compliance > correctness > a working vertical slice > maintainability > UI polish > optional integrations.

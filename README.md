# SocialLess

A native, offline-first iPhone app for intentional social media sessions. SwiftUI, SwiftData and WebKit; iOS 17+; no external runtime dependencies, account, backend or analytics SDK.

## What works

- Optional onboarding, enabled platforms and per-platform 5/10/15/20/30-minute defaults.
- Intention → timed session → terminal completion, with no automatic extension.
- Three finite, clearly fictional offline sample pages. Demo is the default.
- Monotonic active-time accounting, pause/resume, a one-minute warning, crash recovery and idempotent session storage.
- Optional local history, daily/weekly insights, platform breakdowns and a weekly time intention.
- Restricted experimental website browsing: selected platform’s HTTPS origins only; errors/retry/back/close; blocked embedded frames do not replace the main page; no automatic external launch.
- Reversible, opt-in demo filters: per-platform switches, individual navigation rules, live health and restoration without reloading.
- Instagram Reels / Explore navigation pilot: check the current page, explicitly enable, restore without reloading. Starts off unless you explicitly choose to remember your filters.
- Separate confirmed deletion of history and WebKit website data; privacy/limitations in the app.

**All website integrations remain experimental.** The user reported Instagram feed access, expiry and retained sign-in on an iPhone 13 Pro / iOS 27.2, and subsequently reported successful Reels navigation hiding. The user also confirmed restoration and access to messages/stories while filtering; the user also reported that Reels stayed active after ending and reopening a session. Remembered Off, process relaunch and Explore still need device validation. Facebook/TikTok filters, friends-only feeds and Screen Time shielding are unavailable. The offline sample is not a social integration. A blocked service has an offline fallback, never a bypass.

## Run

Open `SocialLess.xcodeproj`, select the **SocialLess** scheme and an installed iPhone simulator, then Run. The project is checked in; XcodeGen is not required. Product copy is English as specified.

On this Mac, Xcode is installed but the global developer directory points at CommandLineTools. Set it for the shell only:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -list -project SocialLess.xcodeproj
xcrun simctl list devices available
xcodebuild -project SocialLess.xcodeproj -scheme SocialLess \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run all unit and UI tests using an actually installed simulator:

```sh
xcodebuild -project SocialLess.xcodeproj -scheme SocialLess \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Regenerate after adding/removing source files or resources:

```sh
python3 scripts/generate_project.py
```

The dependency-free generator owns the project and shared scheme. Make lasting build-setting changes in the generator. The app icon is an original vector construction; regenerate with `swift scripts/generate_icon.swift` if needed.

## Try the reversible filters

Run an **Offline demo** session for any platform, tap **Filters**, and enable **demo filters**. The two synthetic discovery links disappear; sample friends and posts remain. Turn off an individual rule or the main switch to restore those links without reloading. The timer continues while the controls are open. You can also set preferences under **Settings → [platform] → Try demo filters**.

For the **Instagram website pilot**, open the feed → **Filters → Check Reels link**. Checking does not hide anything. If a compatible link is found, switch on **Enable experimental filters**, then tap Done. Turn it off to restore the navigation entry. No match keeps the switch locked. Rule version **0.3.0** also recognizes labeled Reels controls outside semantic navigation and distinguishes unsupported layouts, partial coverage and style blocking. After the previous detector failed, the user reported hiding success following this correction; the user also confirmed that Off restores the entries and messages/stories remain accessible. This does not remove Reels from feed posts or other links. **Explore** starts off and has a separate **Check Explore link** button and switch. Its check leaves active Reels filtering unchanged; it never hides search or tag subpaths. After filters are active, optionally turn on **Remember for Instagram**. Your master/per-rule choices then survive sessions and app relaunch, with automatic compatibility checking before hiding. Unsupported layouts stay visible; updated rule versions require a new check. Off is remembered too. Turn Remember off to keep only the current session’s choices, or use **Settings → Instagram → Forget saved website filters**. Sign-in stays managed separately by WebKit.

The six bundled JSON catalogs separate demo and website rules. Facebook/TikTok website catalogs remain empty and install no filtering script. Instagram's candidate exact navigation destinations are gated behind read-only checks and explicit opt-in. Version 0.3.0 requires a fresh Reels check/Remember choice once; existing sign-in, history and demo settings are retained. Explore has separate remembered consent and never turns on merely because Reels was remembered. The demo's `/socialless-demo/…` paths are fictional, not proposed Instagram/Facebook/TikTok destinations. See `docs/FILTERS.md` for the engine contract and device-validation gate.

## Physical iPhone

1. Select your own unique bundle identifier and Apple development team in Xcode. Keep permanent settings in the generator if regenerating.
2. Connect and trust the iPhone, enable Developer Mode as required by Xcode, select it and Run.
3. Validate the complete offline flow before trying a website. Review the service’s current terms before embedded browsing.
4. Follow `docs/MANUAL_QA.md` and record actual observations in `docs/PLATFORM_COMPATIBILITY.md`. No credentials are needed by the developer or test suite.

No signing identity was available during the initial environment audit. No Screen Time capabilities, entitlement, App Group or extension target is included.

## Time and privacy

The timer counts active foreground time, including loading/error screens. Monotonic clock segments are independent of wall-clock changes. Inactivity/backgrounding pauses time and web media. A terminal state removes the browser before saving. Once a session finishes, another requires fresh setup.

With history enabled, active time is checkpointed approximately once a second and on pause. Cold launch closes a stale checkpoint as `appTerminated`, using only measured time. A crash may lose time since the last successful checkpoint. No time while the process is dead is inferred. With history disabled, no session/checkpoint metadata is stored.

Analytics assign each session to its start date in the current calendar/time zone. This is an explicit aggregation convention, not a per-minute midnight split. Demo sessions are labeled and can be excluded in Insights. Daily hard budgets and history export are deferred.

The website store is WebKit-managed, separate from local history. SocialLess never extracts cookies, credentials, private content or browsing history. Website providers can process data under their own policies. The app has no arbitrary address bar, external launcher, download manager, tracking or remote scripts.

See `docs/IMPLEMENTATION_STATUS.md` for executed verification, `docs/TASKS.md` for remaining work and `docs/RELEASE_CHECKLIST.md` for release gates.

Simulator captures are in `docs/screenshots/`: dashboard, offline session and completion. They show actual running native UI with fictional demo content.



### Import accounts you follow (experimental feed pilot)

Build/install the current app, then open **Settings → Instagram → Import following list**. Export your Followers and following information from Instagram in **JSON**, unzip it in Files, and select **following.json**. Review the preview and tap **Save this list** (or **Replace saved list**). ZIP/HTML and followers files are not accepted. Only account names and the import date are saved locally, excluded from backups; the source export is not copied or deleted.

Start an Instagram **Website** session, open **Filters**, and enable **Only imported accounts**. This separate switch starts Off every session. It hides recognized non-imported authors and identifiable sponsored cards in the home feed; unknown layouts/authors remain visible. It does not automatically obtain/update the list, associate it with your login, fetch missing posts or guarantee friends-only content. Use an up-to-date export from the account currently signed in. Replacing/deleting the list turns the filter Off. Manage/delete it from Settings or the session's Filters screen. Reels/Explore navigation controls and Remember remain independent.

The parser and feed layout are tested with fictional fixtures. Actual file-provider import and current Instagram feed behavior require physical-device validation; see `docs/MANUAL_QA.md`.

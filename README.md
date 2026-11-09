# SocialLess

A native, offline-first iPhone app for intentional social media sessions. SwiftUI, SwiftData and WebKit; iOS 17+; no external runtime dependencies, account, backend or analytics SDK.

## What works

- Optional onboarding, enabled platforms and per-platform 5/10/15/20/30-minute defaults.
- Intention → timed session → terminal completion, with no automatic extension.
- Three finite, clearly fictional offline sample pages. Demo is the default.
- Monotonic active-time accounting, pause/resume, a one-minute warning, crash recovery and idempotent session storage.
- Optional local history, daily/weekly insights, platform breakdowns and a weekly time intention.
- Restricted experimental website browsing: selected platform’s HTTPS origins only; errors/retry/back/close; no automatic external launch.
- Separate confirmed deletion of history and WebKit website data; privacy/limitations in the app.

**Website login, feeds, messages and friends/following destinations are unverified on a physical iPhone. Filters and Screen Time shielding are unavailable.** The offline sample is not a social integration. A blocked service has an offline fallback, never a bypass.

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


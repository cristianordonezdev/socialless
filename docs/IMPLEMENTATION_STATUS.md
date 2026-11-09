# Implementation status

Audit date: 2026-11-09 (America/Mexico_City).

- Starting repository: only `SOCIALLESS_CODEX_MASTER_SPEC.md`; no Git metadata.
- macOS 26.6.2, Apple silicon; command-line Swift 6.4.
- Default developer directory is CommandLineTools, but Xcode exists in `/Applications/Xcode.app`.
- Xcode 27.0 (27A266a), iOS/iOS Simulator SDK 27.0. Commands use `DEVELOPER_DIR` explicitly.
- CoreSimulator is inaccessible from the sandbox; elevated discovery succeeded.
- Available simulator includes iPhone 18 Pro, iOS 27.0, ID `7EE03FCB-6F54-4791-BFE0-846220B62B8E`.
- `security find-identity -v -p codesigning`: 0 valid signing identities. Physical-device distribution pending.
- XcodeGen and Ruby xcodeproj are absent. Use a dependency-free checked-in project generator.
- No real social platform integration has been verified.

The initial shell audit incorrectly suggested Xcode was absent because only the active developer directory was inspected. Direct inspection found the installed Xcode; no global Xcode selection was changed.

## Implemented milestones

**Phase 0:** native project and shared scheme, app/unit/UI targets, reproducible Python generator, original leaf icon, adaptive accent assets, privacy manifest and contributor docs. Bootstrap simulator build succeeded.

**Phase 1:** SwiftUI onboarding, personalization, dashboard, intention/duration setup, offline HTML WebKit sessions, countdown/warning/completion, optional local SwiftData history, insights, settings and privacy. Injected clocks/repositories; once-only completion; pause/resume; measured-only crash recovery; separate UI-test stores. Product copy is English.

**Phase 2:** selected-platform HTTPS navigation restrictions, denial of foreign origins/popups/custom schemes/downloads, visible errors/retry/back/close, media pause and teardown, ordinary WebKit website store and confirmed clearing. Integrations remain experimental. Real-site testing is not implied by the browser shell tests.

**Phase 3 onward:** not implemented. No rule engine, selectors, verified friends/following destination, daily hard budget, export, Screen Time entitlement, shield or extension. These are explicit future tasks; unsupported capabilities are labeled Unavailable.

## Executed verification

Commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and `CODE_SIGNING_ALLOWED=NO`; simulator/test operations required sandbox escalation to reach CoreSimulator. No automatic approval rejection occurred.

| Check | Result / evidence |
|---|---|
| Bootstrap generic iOS Simulator build | Passed; `/tmp/socialless-bootstrap-build.log` |
| Functional app generic iOS Simulator build | Passed; `/tmp/socialless-app-build.log` |
| First complete test run | 23 unit tests passed; 4/6 UI tests passed; `build/OfflineTests.xcresult` |
| Expanded unit tests after fixes | 27 passed, 0 failures; includes actual WebKit foreign-origin cancellation and three local fixtures; `build/RefinedTests.xcresult` |
| Expanded UI tests | 6/7 passed; remaining failure isolated to the test tapping the switch row label rather than its trailing control |
| Final complete test run | **34 passed, 0 failures: 27 unit/integration + 7 UI**, `build/FinalTests.xcresult`, `/tmp/socialless-final-tests.log` |
| Release generic iPhone build (unsigned) | Passed; `/tmp/socialless-release-build.log`, `build/ReleaseDerivedData` |
| Final Release build after accessibility changes | Passed; `/tmp/socialless-release-final.log` |
| Release debug-flag string scan | No UI-testing/reset/fast-session launch flags found in the Release executable |
| `plutil -lint` | Native project and privacy manifest passed |
| Asset JSON / offline fixture static checks | Passed: restrictive CSP; no scripts, remote URLs or forms |
| Project regeneration comparison | Byte-for-byte deterministic |

Initial compiler diagnostics about delegate closure actor signatures were fixed against the installed WebKit headers. A SwiftData predicate macro Sendable warning was removed by using a straightforward ID scan for the small local metadata store. Final compilation has no Swift source warnings; Xcode emits a benign App Intents metadata-extraction warning because this app defines no App Intents.

The first UI run exposed two automation issues: an incorrect test expectation joining two HTML heading lines and a switch tap that did not actually toggle the control before relaunch. The fixture was confirmed in the exported accessibility hierarchy; the assertion now checks the actual content. The next run confirmed the switch remained on immediately after tapping the row center; the test now targets the trailing switch and asserts its new value before terminating. Settings persistence was also hardened to happen in `AppContainer.settings.didSet`, independently of SwiftUI render observation, with a new synchronous repository regression test. The initial failure alone did not establish an on-disk persistence defect.

Original icon generation through AppKit hit a sandbox/runtime trap. The generator was replaced with pure CoreGraphics/ImageIO and ran successfully without a UI connection; no extra dependency was installed.

Final UI tests passed onboarding, cancellation without history, normal local fixture and early exit, timed expiry with browser removal and exactly one record, background/resume counting, maximum Dynamic Type plus landscape reachability, and a real process relaunch after changing the platform switch. Final screenshots are in `build/final-attachments` and selected captures in `docs/screenshots`. Simulator light/large-text/landscape screenshots were inspected; see `docs/ACCESSIBILITY_QA.md`.

Dark dashboard appearance was also inspected on the simulator and saved to `docs/screenshots/dashboard-dark.png`. The appearance was restored to light and the simulator returned to its initial shutdown state after review. These captures contain fictional or empty session data only.

Phases 0 and 1 are complete for the tested simulator environment. Phase 2 browser foundation is implemented and tested offline. The next implementation milestone is Phase 3’s reversible rule framework and synthetic fixtures, followed by physical-device validation before enabling any real-site rule. No live-service behavior is claimed verified.

## Manual/device limitations

- Physical iPhone, real service logins, feeds, messaging, cross-origin auth, media behavior and account clearing are untested.
- iOS 17 is the deployment target; only iOS 27 Simulator is available here. Minimum-OS runtime validation remains pending.
- No valid signing identity was available; no signed archive or installation on a real device was attempted.
- Terms/third-party permission and public distribution review remain pending.
- No formal VoiceOver-on-device, color-contrast audit or minimum-size-iPhone runtime pass yet. Inspected screenshots and Dynamic Type/landscape smoke results are in `docs/ACCESSIBILITY_QA.md`.
- Crash recovery can omit time after the last successful checkpoint. A permanent storage failure leaves completion visible with Retry rather than permitting a new session with unsaved data.
- Website navigation restrictions deliberately break unreviewed cross-domain authentication. The fallback is an explicit new offline demo session.


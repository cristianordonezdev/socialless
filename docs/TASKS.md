# Implementation checklist

## Phase 0 — Bootstrap
- [x] Read the complete specification; audit files, SDK, simulator and signing.
- [x] Native Xcode project, app assets, test targets and reproducible generation.
- [x] Build a minimal launchable app.
- [x] Document architecture, decisions, commands and environment.

## Phase 1 — Offline experience
- [x] Domain models and injected persistence/settings/time services.
- [x] Onboarding and platform personalization.
- [x] Dashboard, intention, duration, countdown and terminal completion.
- [x] Bundled offline pages without network or permissions.
- [x] SwiftData history, crash checkpoints and idempotent completion.
- [x] Insights, settings and confirmed local reset.
- [x] Deterministic time, recovery, persistence and analytics tests.
- [x] Simulator UI tests of complete offline flow and settings persistence (7/7 passed).

## Phase 2 — Restricted WebKit
- [x] HTTPS / selected-platform navigation policy; redirects and popups.
- [x] Errors, retry, back, close, process termination and expiry teardown.
- [x] Separate confirmed website-data deletion.
- [x] Navigation policy tests, real WebKit delegate cancellation and all demo loads.

## Phase 3 — Filters and capabilities
- [x] Versioned JSON schema, platform/mode validation and reversible isolated-world engine.
- [x] Opt-in per-platform/per-rule controls, persisted preferences and in-memory health.
- [x] Synthetic safety fixtures and WebKit/UI regression tests implemented; results in implementation status.
- [x] Record user-reported Instagram browser/expiry/sign-in persistence on iPhone 13 Pro / iOS 27.2.
- [x] Instagram Reels pilot: exact navigation destination, read-only page check, explicit initial opt-in and synthetic coverage.
- [x] Record failed device detection; add narrowly scoped accessibility fallback, unsupported/partial/style-blocked states and mutation regressions (rule 0.2.1).
- [x] Record user-reported Reels navigation hiding after the correction; retain Experimental status and remaining device gates.
- [x] Record physical hide/restore and continued messages/stories access reported by the user.
- [x] Optional remembered Instagram choices, version-bound consent, automatic compatibility checks and forget controls.
- [x] Record user-reported Reels persistence after ending/reopening a session.
- [x] Independent experimental Explore probe, explicit toggle, per-rule remembered consent and regression coverage.
- [ ] Physical Explore hide/restore, remembered Off/process relaunch, broader SPA and auth-flow validation before promoting status or enabling website defaults.
- [x] Capability UI distinguishes demo filters, Instagram's experimental pilot and unavailable Facebook/TikTok filters.
- [ ] Complete real-service matrix with actual device verification dates and installed builds (narrow Instagram browser/filter reports recorded; remaining checks pending).

## Phase 4 — Hardening
- [x] Accessibility / maximum Dynamic Type / landscape / light simulator smoke checks.
- [x] Dark appearance inspection; full physical VoiceOver audit remains pending.
- [x] Privacy and release documentation.
- [ ] Physical iPhone QA of timer, login, navigation and all three services.
- [ ] Third-party terms review before real embedded browsing/distribution.

## Phase 5 — Optional Screen Time
- [ ] Entitlements, signing, individual authorization and on-device validation.
- [ ] Only then: app selection, reversible shields, optional monitor extension.



## User-requested following import / feed pilot (2026-11-13)

- [x] Record Explore hiding as user-reported only; restoration remains pending.
- [x] Implement bounded JSON import, preview, explicit replace, protected local repository and separate delete.
- [x] Implement independent session-off feed filter with conservative author recognition and fail-open restoration.
- [x] Document user-authorized privacy/scope extension without replacing the source specification.
- [x] Complete native/UI regression and Release build; record actual results in IMPLEMENTATION_STATUS.md.
- [ ] Physical JSON file-provider import and current live Instagram feed QA.


## Feed recognition device failure (2026-11-14)

- [x] Record actual user status (0 hidden / 7 unrecognized) and validate the provided export structure without copying account data.
- [x] Reproduce strict header/timestamp limitation with fictional cards.
- [x] Add bounded author-area/media fallback and exact contextual ad badges; preserve ambiguous/caption/profile-name exclusions.
- [x] Run targeted native/UI regression and Release build; 44 tests passed and Release passed, recorded in IMPLEMENTATION_STATUS.md.
- [ ] User retries on current live Instagram; physical correctness/restoration remains pending.

## Feed collapse follow-up — 2026-11-14

- [x] Replace reserved card space with stable collapsed geometry; preserve reversible author re-evaluation.
- [x] Block hidden-card focus/activation and restore owned inert/listeners on teardown.
- [ ] Physical iPhone check: no full-height black gaps, no hidden reel activation during swipes/taps, stable repeated scrolling and allowed-post access.

## Strict feed and video follow-up — 2026-11-14

- [x] Hide unknown home-feed article candidates with explicit false-positive copy; retain collapse/restoration.
- [x] Enable inline video and require deliberate playback; preserve media policy during navigation filter refresh.
- [ ] Verify physical scroll/autoplay/fullscreen, deliberate video controls and remaining unsupported feed layouts.

## Finite feed boundary — 2026-11-14

- [x] User-approved no-match batch end state, document unloading and explicit retry with opt-in retained.
- [x] User reports finite-feed boundary, retry with login/filter retained, Off restoration, expiry on end screen, app reopen and messages/stories access work (2026-11-14).
- [ ] Physical accessibility, slow/recycled pagination, exhaustive matching and wider device/OS verification.

## Independent Stories pilot — 2026-11-14

- [x] Session-only independent Stories switch, first-party viewer guards, contextual ad and optional imported-account filtering.
- [x] Reversible viewer hiding and native shield with explicit home/Off actions; no automatic skipping.
- [ ] Physical Stories ads/followed-account/Off/return-home/video/VoiceOver verification on current Instagram.

## Strict Stories retry — 2026-11-16

- [x] Compare displayed authors with the imported list; shield unknown/ambiguous viewers and avoid route-author approval.
- [x] Extend bounded author-before-media/ad detection and preserve Off/hydration/security/lifecycle behavior.
- [ ] Updated-build physical Stories ad/matching/false-positive/shield/accessibility validation.

## Stories false-positive correction — 2026-11-16

- [x] Replace unknown-author overblocking with visible/unrecognized state; separate ad and outside-list reasons.
- [x] Accept followed header profile links with display names/avatars and add focused regressions.
- [ ] User retries friend/advertiser/unknown story behavior on the corrected build.

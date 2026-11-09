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
- [ ] Rule schema, validated local fixtures and reversible engine.
- [ ] Physical-device validation before enabling any real-site rule.
- [ ] Capability matrix with actual verification dates.

## Phase 4 — Hardening
- [x] Accessibility / maximum Dynamic Type / landscape / light simulator smoke checks.
- [x] Dark appearance inspection; full physical VoiceOver audit remains pending.
- [x] Privacy and release documentation.
- [ ] Physical iPhone QA of timer, login, navigation and all three services.
- [ ] Third-party terms review before real embedded browsing/distribution.

## Phase 5 — Optional Screen Time
- [ ] Entitlements, signing, individual authorization and on-device validation.
- [ ] Only then: app selection, reversible shields, optional monitor extension.


# Release checklist

This is a personal prototype. Version 0.1 source delivery is distinct from public release approval.

## Offline V0.1
- [x] Native Xcode project, source, resources and shared scheme.
- [x] iOS Simulator app build succeeds.
- [x] Unit tests cover boundaries, lifecycle, storage, recovery, calendar grouping and host policy.
- [x] All offline UI tests pass; results recorded in implementation status.
- [x] Onboarding/dashboard/intention/timer/completion/history/settings implemented.
- [x] Offline samples require no account, network or permissions.
- [x] Website and filter capability labels are honest.
- [x] Privacy, limitations and confirmed separate data deletion controls.
- [x] Simulator maximum Dynamic Type, landscape and light UI smoke review.
- [ ] Physical iPhone accessibility / VoiceOver review.
- [ ] Supported minimum iOS version runtime check (iOS 17); current build SDK is iOS 27.
- [ ] Real-device timer/lifecycle/force-quit test.

## Web feasibility / V0.2
- [x] Secure WebKit host source and navigation policy tests.
- [ ] All three service terms and embedding permissions assessed.
- [ ] All three websites assessed on a physical iPhone; actual matrix filled in.
- [ ] Sign-in, redirects, popups, errors, process termination and clear-data behavior verified on device.
- [x] Reversible rule framework and synthetic local fixtures implemented and tested.
- [x] Instagram starts off by default; a read-only check and explicit trial unlock optional version-scoped remembered choices with automatic compatibility checking. Facebook/TikTok catalogs remain empty.
- [x] Record user-reported Instagram feed access, timed expiry and retained sign-in on iPhone 13 Pro / iOS 27.2.
- [x] Record user-reported Instagram hide/restore and messages/stories access while filtering.
- [x] Record user-reported remembered Reels On across sessions.
- [x] Independent Explore check and opt-in, exact-path exclusions and per-rule consent implemented.
- [ ] Physical Explore, remembered Off/process relaunch, broader SPA, auth-flow and accessibility QA before promoting integration status or enabling defaults.

## Screen Time / V0.3
- [ ] Entitlements and signed provisioning available.
- [ ] Individual authorization and deny/revoke flows verified.
- [ ] Only selected apps shielded, with a reliable disable control.
- [ ] Any extension tested independently on device.

## Public distribution
- [ ] Terms/legal review and third-party permissions where required.
- [ ] Privacy manifest, labels and data deletion behavior re-audited.
- [ ] Accessibility, supported-device and localization pass.
- [ ] Signing/archive/distribution validation.
- [ ] App Review minimum functionality and third-party-service requirements reviewed.


## Following import / feed pilot gates

- [x] Explicit user-requested scope extension documented (ADR-016); source spec preserved.
- [x] Bounded explicit JSON import, preview, protected separate storage, no uploads and deletion without touching source/history/login.
- [x] Experimental session-off feed filtering; unknown authors/layouts remain visible; lifecycle/failure restoration covered by synthetic native tests.
- [x] Unsigned iPhone Release build; test fixture flags excluded; no Screen Time targets/entitlements or runtime dependencies added.
- [ ] Physical Files provider import / real export variants and current Instagram feed author recognition.
- [ ] Real hide/restore, dynamic feed, account switching, accessibility/performance and distribution/terms review.

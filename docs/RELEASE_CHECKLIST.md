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
- [ ] Optional rule framework and local fixtures implemented and tested.
- [ ] No real-site rule enabled until its own verified scope and kill switch exist.

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

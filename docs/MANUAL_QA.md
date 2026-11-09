# Manual QA

## Offline simulator/device flow

1. Fresh app → onboarding → personalization → dashboard. Also test Skip and zero enabled platforms.
2. Start each platform in demo mode. Confirm finite fictional content and no login/permission prompt.
3. Choose each intention and 5/10/15/20/30-minute length. Cancel setup; history must not change.
4. Close early; exactly one summary appears. Start another only through explicit setup.
5. Wait for the 60-second warning and expiry. Browser must disappear; Back and gestures must not reopen it.
6. Background, lock, Control Center and incoming interruptions; active duration must pause. Resume without resetting elapsed time. Verify media pauses on real websites when permitted.
7. Force quit during a measured session; reopen. Only the last successful checkpoint should be recovered once as an interrupted session.
8. Disable history; finish a session; no new record or checkpoint should be stored.
9. Change default duration/platform; terminate and relaunch; preferences must persist.
10. Delete history, cancel deletion, clear WebKit data separately, reset preferences. Confirm each scope.
11. Insights: zero data, multiple platforms, include/exclude demos, seven days, old history, weekly intention. Document start-day attribution across midnight and time-zone changes.

## Accessibility and layout

- VoiceOver: onboarding, platform selection, intent, countdown label/value, warning, completion, settings, error/retry and textual analytics.
- Dynamic Type accessibility sizes; small phone; portrait and landscape; light/dark; Reduce Motion.
- Verify readable contrast, no color-only statuses, minimum tap sizes and scroll reachability of primary actions.
- Confirm the countdown does not announce every refresh. Verify completion/warning navigation and reading order on device.

## Real service matrix (pending; requires user-authorized device login)

For Instagram/Facebook/TikTok: terms/embedding review → opening → permitted login → feed → available official friends/following navigation → same-site/back → redirect/popup/custom-scheme failure → no silent escape → expiration → clear login data. Never type credentials into a native SocialLess form or share them with the developer. Do not bypass browser restrictions or CAPTCHA.

Cross-domain sign-in failures are expected under the strict policy; record the needed origin and review before proposing an exception. Failure must leave offline functionality usable. Do not invent selectors or populate Verified statuses without observation.

## Deferred Screen Time QA

Before implementation: entitlement, code signing and personal/individual authorization on a physical iPhone. Later test denied/revoked access, selected tokens only, disable restrictions, app termination/reboot/time-zone/DST. Never claim selective changes to another app.


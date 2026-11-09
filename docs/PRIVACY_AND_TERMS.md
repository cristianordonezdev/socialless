# Privacy and service boundaries

SocialLess has no account, server, advertising ID, analytics SDK or tracking. With user-visible local history enabled, it stores platform, intention, demo/website mode, session UUID, start/end/checkpoint timestamps, measured active duration, configured duration and completion reason. Disabling history stops future session/checkpoint writes; confirmed deletion removes existing records.

SocialLess never extracts website credentials, cookies, authentication tokens, account identifiers, message text, feed/media content, friend lists or browsing history. WebKit manages the website’s ordinary persistent data; a separate confirmed action clears all WebKit data belonging to this app. It cannot clear Safari or native-app sessions. Demo mode uses an ephemeral store and bundled pages with a restrictive CSP and no remote resources.

The website provider controls its own login, content and data collection. The app has no private API integration, proxy, network interception, user-agent spoofing or challenge bypass. HTTPS navigation is restricted by parsed host; no query-bearing URL or error payload is logged by app code. Public WebKit permission delegates deny camera/microphone requests. No native sensitive-resource permission descriptions or entitlement requests are included.

SwiftData uses the app sandbox and OS-provided data protection. No cloud sync is configured. OS backups may include app data under the user’s device settings. There is no claim that deleting local data deletes the provider’s records or existing backups.

The bundled privacy manifest declares no developer data collection/tracking and app-only UserDefaults use (`CA92.1`). The timer uses `ContinuousClock`, not a direct `systemUptime`/`mach_absolute_time` call. Re-audit the manifest and privacy disclosures whenever APIs, extensions or data flows change.

## Review before real embedded use or distribution

The app is a personal prototype, not an approved third-party client. Service terms/permission review, website device QA and App Store review are still pending. Do not equate a successful simulator build with provider authorization or App Store eligibility. Filters and Screen Time are unavailable. Any future shield blocks the whole chosen app and needs separate entitlement/device validation.

Official references consulted during implementation (2026-11-09):

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — review third-party service permission and minimum functionality requirements before distribution.
- [WebKit navigation delegate](https://developer.apple.com/documentation/webkit/wknavigationdelegate) and [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview) — public browser APIs; installed Xcode 27 headers were also inspected for exact signatures.
- [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock) — clock abstraction; elapsed-duration behavior is covered by injected-clock tests.
- [SwiftData](https://developer.apple.com/documentation/swiftdata) — native local persistence, verified with a recreated store test.
- [Privacy accessed API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and [TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).

Some Apple documentation endpoints returned JavaScript-only pages/unsupported Markdown to the web reader. Relevant public signatures were checked against installed SDK headers, official indexed documentation and actual compilation. No live-service behavior was inferred from these sources.


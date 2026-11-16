# Architecture decisions

## ADR-001 — Native SwiftUI and WebKit
Accepted. Target iPhone, iOS 17+. Native frameworks keep UI accessibility, lifecycle and browser behavior close to platform APIs. No React Native/Flutter or third-party runtime dependencies.

## ADR-002 — Local storage, no backend
Accepted. SwiftData for optional session metadata; UserDefaults for settings. A separate WebKit data store handles website sessions without any app-level cookie/credential access. Device backups are governed by the user’s system settings.

## ADR-003 — Friends-only is unavailable
Accepted. No provider-authorized friends feature has been verified in mobile WebKit. All three website hosts are experimental. The later Instagram pilot in ADR-012 is navigation-only; it does not change friends-only availability. Do not claim friend identification or ship candidate selectors as verified.

## ADR-004 — App timer is independent of Screen Time
Accepted. Injected monotonic active segments count foreground activity only. No background timer. Start-day aggregation in the user’s current calendar is documented; daily hard budgets are deferred. Expiry is terminal regardless of storage success.

## ADR-005 — Reversible navigation filtering, demo first
Accepted; implemented in Phase 3 after the phases 0–2 foundation. Bundled JSON catalogs are scoped to both platform and demo/website mode, and validated before script creation. `hideAnchorByPath` uses segment-boundary matching on parsed first-party HTTPS URLs inside navigation elements; ADR-012 adds exact destinations. Protected authentication paths and article/form/dialog links are excluded. An isolated main-frame script owns a unique marker and style rather than changing original attributes or removing DOM nodes. Restore removes only that state, preserving the website's own visibility choices.

A throttled observer handles dynamic navigation; native URL observation handles SPA route changes. Health and bounded per-rule counts stay in memory. Demo filters are opt-in with independent platform preferences. Website catalogs initially shipped empty; ADR-012 adds a gated Instagram trial while the others remain empty. Fictional demo routes never become real-site defaults. This engine does not intercept traffic, identify friends, remove posts/videos, block routes or scrape content.

## ADR-006 — Fail closed, offer the offline demo
Accepted. A failed or cross-origin login shows a recoverable error. No automatic Safari/native-app launch, broad OAuth allowlist or user-agent spoofing. The user can end a session and explicitly start the offline demo.

## ADR-007 — Screen Time waits for entitlements and device QA
Accepted. No target, framework, token storage, authorization prompt or shield is included. Individual authorization, provisioning and device validation precede implementation of optional whole-app shielding.

## ADR-008 — Reproducible native project without a package manager
Accepted. Xcode exists, XcodeGen/xcodeproj do not. A small Python standard-library generator produces a checked-in native project and shared scheme. It adds no runtime dependency and avoids changing global toolchain settings. Regeneration discovers source/resources deterministically.

## ADR-009 — English copy and honest demo data
Accepted. The specification requests English, localization-ready product copy. Demo content is fictional, finite, local, and separately labeled in history. Native SF Symbols, system typography, adaptive colors, original leaf icon and textual chart alternatives support a calm UI.

## ADR-010 — Blue visual identity
Accepted at the user's request after trying the first offline demo. Replace the green accent with cobalt blue (`#335CDB`) in light appearance and a softer blue (`#8FAEFF`) in dark appearance. Apply the same direction to the original icon and all bundled demo pages, including avatars, borders and illustrations. Keep neutral system backgrounds and native controls. This is a visual change; session, storage and navigation behavior are unchanged.


## ADR-011 — Frame-aware navigation failures
Accepted after reproducing the user's immediate website-error symptom with a local iframe. Keep the selected-platform HTTPS allowlist for top-level documents. Treat blank/srcdoc child frames as local documents; cancel disallowed embedded navigation independently. A blocked child frame must not make a loaded main page unusable. For unsupported top-level links or new windows, preserve a committed page and present a dismissible notice; an initial failure still has a clear retry/end-session fallback. This changes error presentation and narrow local-child-document handling, not cross-origin authentication permissions or filtering availability.

## ADR-012 — Session-only Instagram Reels pilot

Accepted 2026-11-10 after the user reported working Instagram browsing, expiry and retained sign-in on iPhone 13 Pro / iOS 27.2, and asked to continue. That report does not establish a DOM selector. Use the specification's candidate exact Reels destination only inside semantic navigation; exclude individual videos and article/form/dialog links. Before a user can opt in, a one-shot local check must detect a visible compatible link. Checking does not hide anything, observe changes or transmit page data; only bounded counts reach native controls. Unknown layouts leave the switch locked and timed browsing intact.

The master switch is off in every website session and readiness is held only in memory. This provides a concrete on-device trial without enabling candidate defaults or labeling them verified. Keep rule availability Experimental and document real hide/restore/SPA/auth outcomes before considering persisted activation or additional destinations. Do not broaden matching based only on a failed check. Login remains in WebKit's ordinary store independently of the pilot.

## ADR-013 — Explicit accessibility fallback after failed Reels detection

Accepted 2026-11-13. The user confirmed No matching navigation links. Reproduce the strict semantic-navigation limitation with an unmarked synthetic layout, then extend only the validated Instagram Reels rule: exact first-party Reels destination plus semantic navigation or an anchor/SVG accessibility label of Reels. Do not replace the selector with a broad video/post match or infer actual Instagram HTML from a fixture. Unknown exact-destination links remain visible and produce unsupported/partial health; actual device hide/restore remains unverified.

Observe relevant label/style/marker edits with the existing throttle and disconnect during owned writes. If hiding is overridden, restore and report style blocking explicitly. These states distinguish missing targets, unsupported controls and failed hiding without exporting DOM, URLs or account data. Keep the existing per-session check and opt-in.


## ADR-014 — Optional remembered Instagram filters with local compatibility checks

Accepted 2026-11-13. The user confirmed hiding, Off/restoration and continued access to messages/stories, then requested the next milestone. Supersede ADR-012's session-only restriction for an explicit optional remembered trial; default activation remains off and availability remains Experimental. Do not infer broader SPA/auth/device QA from that report.

After an active manual trial, Remember stores only master/per-rule choices and the bundled catalog version. New sessions accept only matching Instagram website consent. The runtime checks visible, recognized navigation before applying automatically; missing or partly recognized layouts leave all controls visible, and late page updates may retry via the bounded 300ms observer. Auth paths remain excluded. Catalog changes require a fresh manual check and consent. Off is persisted, forgetting preserves current-session choices, and Settings offers a separate forget action. Login and session history remain independent. No readiness, page content or URLs are stored.


## ADR-015 — Independently gated Explore navigation

Accepted 2026-11-13. After user-reported Reels persistence between sessions, add Explore as an Experimental candidate from the source specification, not a claim of live DOM support. Catalog 0.3.0 requires fresh consent; Explore starts off, matches only exact first-party Explore navigation, and excludes search/tag/location subpaths, posts, forms, dialogs and protected auth routes. A separately revisioned read-only probe leaves the active runtime untouched and cannot opt in. Reels readiness/remembering never authorizes Explore; explicit additional-rule consent IDs are stored only with remembered choices. Runtime compatibility and fallback operate per rule so unsupported Explore cannot disable compatible Reels. No live account or private page capture is used. Device validation is still required.


## ADR-016 — User-imported following snapshot and experimental feed author filter

Accepted 2026-11-13 after the user explicitly requested using the accounts they follow, accepted the proposed local export import, and instructed implementation. This is a narrow user-authorized extension to the source specification's original prohibition on storing social identifiers and navigation-only scope. The source specification is preserved. Only account names explicitly chosen through an import and the local import date may be persisted; website authors, posts, URLs, credentials, cookies, and messages must never be persisted or logged.

Import only a bounded JSON object with relationships_following, accepting title or string_list_data.value account fields. Reject ambiguous/malformed records, empty lists, follower-array exports, ZIP/HTML and excessive input as a whole; never silently substitute a partial list. Show a preview and require Save/Replace before changing existing data. Use an injected repository, atomic protected file storage in a backup-excluded directory, and a separate confirmed deletion. No automatic social-graph extraction, private endpoint, network upload or live synchronization.

The separate Experimental feed filter starts Off every session and turns Off on list replacement/deletion. It applies only to the first-party HTTPS home route, using a conservative candidate semantic main/article/header author link plus timestamped post permalink. Multiple or missing recognizable header authors remain visible. It does not fetch posts, guarantee a complete feed, or infer the logged-in account. The user must import the correct account's current export. Dynamic updates re-evaluate authors; temporary counts/status alone cross from an isolated WebKit world to native UI. Off, pause, failure, navigation and shutdown restore owned markers. Navigation catalog 0.3.0 and its existing consent remain independent and unchanged. Synthetic tests do not validate Instagram's live DOM.

## ADR-017: Independent experimental Stories filter — 2026-11-14

User explicitly requested filtering Stories ads after validating feed stability. Add a separate session-only Off-by-default Stories switch. In a strictly guarded first-party /stories/handle/numeric-id viewer with one outer semantic main/dialog and one semantic header, exact contextual sponsored badges hide the viewer. A saved user-imported following list also blocks accounts outside that list; without a list, only recognized ads are blocked. No automatic story skipping, playback or following fetch. A native shield offers return home or turning the filter Off. Unknown viewer layouts remain visible with unsupported health rather than claiming ad removal. This extends filtering to an explicitly authorized surface without changing the source spec or saving website data. Keep Experimental pending device QA. Login, feed opt-in/end state and navigation rules remain independent.

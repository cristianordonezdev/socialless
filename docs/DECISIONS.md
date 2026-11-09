# Architecture decisions

## ADR-001 — Native SwiftUI and WebKit
Accepted. Target iPhone, iOS 17+. Native frameworks keep UI accessibility, lifecycle and browser behavior close to platform APIs. No React Native/Flutter or third-party runtime dependencies.

## ADR-002 — Local storage, no backend
Accepted. SwiftData for optional session metadata; UserDefaults for settings. A separate WebKit data store handles website sessions without any app-level cookie/credential access. Device backups are governed by the user’s system settings.

## ADR-003 — Friends-only is unavailable
Accepted. No provider-authorized friends feature has been verified in mobile WebKit. All three website hosts are experimental, and all filters are unavailable. Do not guess routes, claim friend identification or ship candidate selectors as verified.

## ADR-004 — App timer is independent of Screen Time
Accepted. Injected monotonic active segments count foreground activity only. No background timer. Start-day aggregation in the user’s current calendar is documented; daily hard budgets are deferred. Expiry is terminal regardless of storage success.

## ADR-005 — Filtering remains a later vertical slice
Accepted. The initial delivery covers phases 0–2. Phase 3 will add versioned, reversible, platform-scoped rules and isolated fixture tests before any rule is enabled on real sites. No interception or content scraping is needed. Current capability UI says Unavailable and does not expose a nonfunctional switch.

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


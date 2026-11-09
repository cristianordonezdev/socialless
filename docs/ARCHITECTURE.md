# Architecture

- **Composition:** `SocialLessApp` opens `AppContainer`, injecting a session repository, settings repository and time source. A storage-open failure shows a recoverable error; it never deletes or silently replaces the store.
- **Domain:** Codable platform/intent/summary/checkpoint/settings models; `SessionEngine` coordinates the clock and storage behind MainActor protocols. SwiftUI observes native Observation state.
- **Clock:** `ContinuousClock`-relative durations, accumulated active segments. Wall time supplies human-readable timestamps only. A 200ms UI task refreshes state; it is not the source of elapsed time.
- **State:** idle → active ↔ paused → completed. Warning derives from `0 < remaining <= 60`. Closing at/after the deadline records expiry. Completed state is set synchronously before persistence; repeat finish events are no-ops.
- **Persistence:** SwiftData stores encoded metadata in two models: completed records and a single active checkpoint. UUID uniqueness plus existing-ID checking provides idempotence. Finish and checkpoint removal share a context save; failures roll back. Autosave is disabled to avoid partial mutations.
- **Recovery:** startup finalizes only the checkpoint’s measured duration. Live state is never resumed after a process restart. Local history opt-out avoids writing both completed records and checkpoints.
- **Settings:** versioned Codable payload in app-only UserDefaults. Invalid duration preferences fall back to 10 minutes. Corrupt payloads are reported, not overwritten.
- **UI:** native onboarding, dashboard, full-screen intentional session flow, insights, settings and privacy. The full-screen flow owns a cancellable ticker. The root observes scene activation for timing.
- **Browser:** one `WKWebView` per session. A controller owns security delegates and display state; a representable owns placement only. Disappearance disables interaction/media and stops loading. Completion removes the host; delegates also consult live session state before navigation.
- **Demo:** app-bundled HTML via `loadHTMLString`, nonpersistent WebKit store, restrictive CSP, no scripts/forms/network resources. Only its initial `about:blank` document navigation is allowed.
- **Website:** ordinary WebKit store; standard platform home only. HTTPS and exact root / dot-delimited subdomains of the selected service. No credentials in URLs, nondefault ports, HTTP, file URLs, custom schemes, external origins or new-window launch. Download requests and unsupported main-document MIME types are rejected. No user-agent spoofing, remote scripts or JavaScript content extraction.
- **Tests:** hosted XCTest tests for domain/persistence/security, plus XCUITest flows. Debug-only UI launch flags use a separate preferences suite/store. Reset flags cannot touch normal user data. Release builds ignore them.

## Deliberate limits

No friends detector, DOM filter scripts, verified social destinations, OAuth exceptions, Screen Time frameworks, extensions or server. Website subresource traffic remains controlled by WebKit and the provider; the navigation allowlist is not advertised as a network content blocker. Native-app and Safari time is not measured.

The V0.1 data set is small; the idempotence check currently scans record IDs on completion to avoid an SDK predicate-concurrency diagnostic. It does not deserialize social content (none is stored). Add an indexed fetch when large histories warrant it and the supported toolchain passes the predicate check cleanly.


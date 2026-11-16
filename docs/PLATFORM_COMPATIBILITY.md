# Platform compatibility

Last updated: 2026-11-13. Repository app version 0.1.0 (1). User-reported physical device: **iPhone 13 Pro, iOS 27.2**. The installed build number and exact test time were not supplied. All integrations remain Experimental.

| Capability | Instagram | Facebook | TikTok |
|---|---|---|---|
| Local demo fixture | Implemented | Implemented | Implemented |
| Standard HTTPS home host | Implemented, experimental | Implemented, experimental | Implemented, experimental |
| Website opens on physical iPhone | User reported working | No specific follow-up | No specific follow-up |
| Authenticated access / sign-in persistence | User reported retained across sessions; fresh login/challenges untested | Untested | Untested |
| Real feed available | User reported posts visible | Untested | Untested |
| Friends/following web destination | Unavailable; unverified | Unavailable; unverified | Unavailable; unverified |
| Messages/stories/Reels surfaces | User reported visible; sending/playback untested | Untested | Untested |
| Countdown / terminal expiry | User reported working | Untested | Untested |
| Reversible demo navigation filters | Implemented; synthetic only | Implemented; synthetic only | Implemented; synthetic only |
| Real-site DOM rules | Reels hide/restore and messages/stories access user-reported; Explore unverified; Experimental | Unavailable; empty catalog | Unavailable; empty catalog |
| Remembered website filters | Reels On after session restart user-reported; process relaunch/Off and Explore pending | Unavailable | Unavailable |
| Cross-origin authentication | Blocked; no reviewed exceptions | Blocked; no reviewed exceptions | Blocked; no reviewed exceptions |
| Deep links/external apps | Blocked by policy | Blocked by policy | Blocked by policy |
| Native app shielding | Unavailable | Unavailable | Unavailable |

Demo catalogs are version `0.1.0`, schema `1`, marked Experimental, opt-in, and only target fictional `/socialless-demo/` paths. They are separate from website catalogs. No real-service selector/path was inferred from the samples.

Simulator offline tests do not establish website compatibility. The agent did not access a real account or live feed; the observations below come from the user.

## Remembered Reels follow-up and Explore pilot — 2026-11-13

The user reported ending and reopening a session with the Reels filter still active. This is a narrow remembered-On result; process termination, remembered Off and exact installed version were not specified. Device context remains the prior iPhone 13 Pro / iOS 27.2 report.

Catalog 0.3.0 adds an independently gated Explore candidate, off by default. It is implemented against fictional local fixtures only; physical detection, hiding/restoration, search behavior and remembering Explore are pending. Only exact Explore navigation is targeted, not search/tag/location subpaths or recommendations in the feed. A separate check leaves active Reels filtering unchanged, and Reels consent cannot activate Explore. This catalog change requires rechecking/remembering once. Integration status remains Experimental.

## Instagram reversibility follow-up recorded 2026-11-13

The user explicitly confirmed both requested outcomes: switching filters off returns the Reels entries, and messages/stories remain accessible while filters are on. This adds user-reported reversibility and continued navigation to those surfaces. It does not establish sending messages, media playback, every SPA route, login/consent/recovery behavior or performance. The earlier device context remains iPhone 13 Pro / iOS 27.2, with installed build/rule version unconfirmed.

The next implementation adds optional remembered master/per-rule choices, tied to the catalog version and checked automatically before hiding. First use still requires a manual check and an active trial; remembering defaults off. This new saved-choice flow has not been tried by the user yet. Keep status Experimental and `lastVerifiedAt` null for full integration QA.

## Instagram hiding success reported 2026-11-13

Following delivery of pilot 0.2.1, the user reported that filtering now works and Reels entries no longer appear. The prior iPhone 13 Pro / iOS 27.2 is the device context; app/rule versions and precise test time were not reconfirmed. This supports navigation hiding on the user's current layout, not removal of Reels feed posts or every route into Reels. Restoration and messages/stories access were subsequently confirmed as recorded above. Broader navigation and background/resume remain unconfirmed; status stays Experimental.

## Instagram detection failure reported 2026-11-13

The user reported that Reels and the Reels section remained available. They then confirmed **No matching navigation links** after Check Reels link. Detection did not pass, so the existing pilot could not be enabled. This is a failed physical-device compatibility check, not proof that CSS injection failed. Reels appearing as feed posts are outside this navigation-only pilot's scope.

The original detector required a `nav` / `[role="navigation"]` ancestor. A synthetic alternate layout with an exact Reels destination and a labeled icon, but no such ancestor, reproduced that limitation. Pilot 0.2.1 also recognizes a Reels accessibility label on an exact-destination anchor or its SVG icon. It reports unsupported layouts, partial coverage and style blocking separately, and reconciles label/style/marker mutations. These are synthetic regression results, not a capture of the user's Instagram DOM; they do not establish the precise live-site cause or prove the fix on device. No URLs, credentials or page content were requested.

## Instagram observation recorded 2026-11-10

The user confirmed the browser now opens, identified an iPhone 13 Pro running iOS 27.2, and reported access to the Instagram feed with posts, messages, Reels and stories visible. The countdown continued and expiry exited the browsing session. A subsequent SocialLess session retained the Instagram sign-in. No account identifiers, credentials, content, website URLs or screenshots were requested or recorded.

This supports a narrow browser-feasibility result on one device/account. It does not verify message sending, media playback, a Following destination, fresh login/recovery/consent, background media, clearing website data, Facebook/TikTok or any DOM filter. Integration status stays Experimental; `lastVerifiedAt` remains null for filter rules.

The initial pilot targeted only the exact `/reels` or `/reels/` navigation destination inside `nav` / `[role="navigation"]`, excluding articles, forms and dialogs. The 0.2.1 update above adds a narrow accessibility fallback. The destination originated as a candidate from specification §3.2/§8.2, **not captured Instagram DOM**. A one-shot local check must find a visible compatible link before initial enabling is allowed; only bounded counts and known states reach Swift. The check itself hides nothing. Unknown layouts remain untouched. New sessions start off unless the user explicitly remembers choices for the current catalog; that mode checks visible recognized controls automatically and leaves partially recognized layouts unmodified. No account state is cleared.

Only `https://www.instagram.com/`, `https://www.facebook.com/` and `https://www.tiktok.com/` are standard starting URLs, not friend-only destinations. The policy permits HTTPS root and dot-delimited subdomains for the selected service, with no external exceptions. The WebKit store is ordinary and the user agent is unchanged.

## User-reported browser failure

2026-11-09: the user reported an immediate unsupported-navigation error when opening all three website modes. Device/OS was not supplied. They also confirmed the demo's Discover/Short videos links disappear while posts remain, which is the intended navigation-only behavior.

A deterministic local WebKit fixture reproduced the exact error: a rejected foreign iframe set the global error message, replacing the entire main page. The controller now handles subframes independently, permits only exact blank/srcdoc child documents in addition to the existing selected-service HTTPS policy, and cancels other embedded navigation without hiding the main document. No external domain was added to the allowlist. Existing pages remain visible behind a dismissible notice for unsupported top-level links/new windows.

This reproduced and corrected a shared browser defect. The user subsequently confirmed successful Instagram browsing as recorded above. That report does not independently establish the cause or outcome for each other service.

## Physical-device observation template

For each new verification, record: service, feature, date, app/rule version, device, iOS, region if relevant, actual observed behavior, status (Verified/Experimental/Unavailable), reproduction and fallback. Do not include passwords, cookies, query-bearing URLs, account identifiers, feed contents or screenshots containing private messages.

Maintain separate user-reported observations and independently reproduced verification. Provider announcements or simulator demo success are not substitutes for device observations.



## Following import/feed pilot and Explore report — 2026-11-13

The user reported Explore was no longer visible. Record this as narrow user-reported hiding on the prior iPhone context, without assuming restoration, process relaunch or a new device/version. The new imported-account home-feed pilot remains **Experimental / physical QA pending**. It accepts a user-selected JSON snapshot, not an automatic connection to Instagram. The conservative semantic author detector is synthetic and may find no compatible posts in current Instagram. Unknown posts remain visible; no complete friends-only feed is promised. File-provider import, account switching/stale lists, dynamic actual markup, restore, lifecycle, accessibility and performance must be checked on device. Facebook/TikTok feed filters remain unavailable.


### Feed detector retry — 2026-11-14

User-reported following import succeeded, but the active filter showed 0 hidden / 7 unrecognized with unfamiliar accounts and ads still visible. The user-provided JSON structure is compatible with the importer; no live DOM was obtained. Corrected a reproduced synthetic limitation requiring semantic headers and timestamped permalinks, with a bounded author-before-media fallback and contextual English/Spanish sponsored badges. Physical filtering correctness is **still unverified**; a compatible list and passing synthetic tests cannot establish actual site detection. Saved list/login/navigation preferences are unchanged. Retry on device and report only aggregate health/counts and hide/restore behavior.

### Feed scrolling follow-up — 2026-11-14

User reports Hidden posts 66, Unrecognized rapidly alternating 7/11, and involuntary feed scrolling that prevented checking filter correctness. This is a failed usability result, not a Verified integration. The correction preserves hidden-card geometry, reconciles only changed markers and reuses the same-document runtime. Blank reserved areas are intentional. Fresh physical QA of scrolling, author/ad matching, reversal and accessibility is still required on the updated build. Existing Reels/Explore evidence does not validate this independent feed feature.

User follow-up: scrolling appeared improved, but reserved black spaces and an unintended suggested/unknown reel opening remained. User explicitly requested collapsing filtered posts. Updated implementation collapses recognized cards once and adds inert/hidden-event guards; it supersedes the reserved-space approach. Physical touch/scroll, classification and accessibility verification on this revision remain pending.

2026-11-14 follow-up: user confirms no remaining hidden-post spaces, but accounts outside the imported list remain visible and scrolling triggers video playback/fullscreen. Strict hiding of unknown article candidates and deliberate inline media policy are implemented; both need physical revalidation. Spacing success does not imply feed matching success.

2026-11-14 finite-feed choice: user explicitly requested ending after a new batch without matching posts. Runtime now settles new candidate nodes and native code unloads the live document on no-match, showing a retry/end screen while the timer continues. This is a local finite-feed boundary, not proof that later matches do not exist or control of Instagram pagination APIs. Physical end/retry/login/accessibility verification remains pending.

## User-reported stability confirmation — 2026-11-14

The user confirmed that all four requested checks work: Try again retains login and feed filtering; switching the filter Off restores posts; timer expiry ends the session even on No more matching posts; closing/reopening the app and accessing messages/stories work. Prior reports separately confirm removal of hidden-post spaces, prevention of automatic reel playback and operation of the finite-feed boundary. Record these as user-reported device results, using the previously supplied iPhone 13 Pro / iOS 27.2 context; exact installed build and current device/OS were not reconfirmed. No credentials, social content, handles or URLs were requested or stored.

This closes the requested basic stability retry. Keep integrations Experimental: exhaustive author/ad detection, false positives, slow/recycled pagination, deliberate custom video controls, accessibility, large text/dark mode and wider OS/device coverage remain open. No runtime changes or new tests in this documentation-only update; previous actual build/test results remain recorded below.


2026-11-14 Stories extension: user requests filtering ads in Stories. Added an independent experimental session-only pilot with strict synthetic route/viewer/header candidates, contextual ad labels and optional imported-account matching. This is not covered by prior user confirmation that Stories remained accessible. Current real Stories detection/hide/restore/native actions/playback/accessibility require separate physical QA. Unsupported layouts or unlabeled ads may remain visible; no automatic skipping.

2026-11-16: user reports Stories ads still visible; strict imported-author revision is implemented using visible author evidence instead of URL account and native shielding for unknown/unsupported viewers. This supersedes prior unsupported-viewer fail-open behavior only when a saved list exists. Updated physical Stories coverage/false-positive/restoration verification remains pending.

2026-11-16 false-positive follow-up: user reports every friend story blocked with perceived sponsored classification. Strict unknown blocking is superseded: unknown stories remain visible; display-name/avatar header links are accepted; only positive sponsored/outside-list evidence blocks with separate native reasons. Updated physical matching/false-positive validation is pending. No claim that all ads are removed.

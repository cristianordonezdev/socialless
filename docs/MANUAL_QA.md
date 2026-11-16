# Manual QA

## Feed scroll regression gate — 2026-11-14

On the updated build, with the already imported list, enable Only imported accounts on the Instagram home feed. Scroll through multiple loaded batches, stop midway, open/close Filters, background/resume, and toggle Off/On. Confirm the viewport does not jump by itself, unchanged cards do not cause rapid count oscillation, and recognized hidden cards collapse without retaining full-height black areas. Initial On/Off can move content once; unchanged cards must not repeatedly change layout. Tap/swipe across former card locations and verify no hidden reel opens; allowed cards and navigation must remain usable. Counts describe currently mounted candidate articles and may change as Instagram loads/recycles them; they are not cumulative. Verify allowed accounts remain readable, recognized ads/non-imported authors hide, and Off restores them. Unknown authors intentionally remain visible. Test VoiceOver focus, video behavior, dark mode and large text. User's prior Hidden 66 / Unrecognized 7–11 report demonstrated instability, not successful filtering. These device checks remain pending.

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

## Reversible filters

1. Start each offline platform with filters off. Open **Filters**, enable demo filters, close the sheet: only Sample Discover / Sample Short videos disappear. Friends and posts remain.
2. Disable one rule: only its link returns. Disable the main switch: all app-hidden links return without reload or scroll reset. Original page-hidden elements must stay hidden.
3. Reopen demo controls, terminate/relaunch, and start another demo: settings persist. A different platform retains independent settings. The website pilot starts off unless Remember was explicitly enabled for the current rule version.
4. Background/resume while enabled; close normally and expire while the sheet is open. No stale sheet, interaction, observer or script should survive completion.
5. Review health: Off, Active, No matching links, Paused, Unavailable. No matches is not evidence that recommendations were removed. A failed rule should leave timed browsing usable.
6. Facebook/TikTok Website mode must show unavailable filters with no injected filter script. Instagram without remembered consent starts off with its enable switch locked until a compatible navigation link is detected.
7. Before enabling website defaults or marking filters Verified: document permitted on-device observation (device/OS/date/app/rule version), exact navigation-only scope, authentication/consent/recovery exclusions, reversibility, SPA behavior and failure fallback. Add sanitized synthetic fixture cases, not private website captures. Candidate routes must never become active defaults without device validation.

## Instagram Reels pilot — next physical-device pass

Baseline reported by the user, recorded 2026-11-10: iPhone 13 Pro / iOS 27.2, feed visible, messages/Reels/stories surfaces visible, countdown and terminal expiry working, sign-in retained on the next session. Sending messages, playing media, fresh login, background behavior and clearing login data were not confirmed.

1. Install the updated build without deleting the app or its website data. Start Instagram → Website. Sign-in should remain as before, subject to Instagram's own session policy.
2. From the feed, open **Filters → Check Reels link**. Without remembered consent, Enable must be off/locked before checking. After checking, nothing on the page should disappear. Record only the displayed status and count, never URLs/account content.
3. If **Compatible navigation link found** appears, enable experimental filters, tap Done, and confirm only the Reels navigation entry disappears. Confirm the feed, stories and messages entry remain usable. Reels in posts/other links are outside this rule's scope.
4. Turn off the master switch. The same entry must return without page reload, scroll reset or lost sign-in. Try its individual switch too.
5. Navigate within the site and return home, background/resume, then repeat Off/On. Check login/consent/recovery only when naturally encountered; no filtering should affect these pages. Do not trigger account challenges just for this test.
6. Close early and start a new session, including via the completion screen. Without Remember, the pilot must start off and require a fresh check; sign-in and history are independent. Also expire while controls are open: the entire browser and sheet must close.
7. With rule version **0.3.0**, record the precise status after checking: **No matching navigation links** means no visible supported entry was found; **Navigation links found · layout unsupported** means the destination exists but its control is unrecognized. After enabling, **Some navigation filters could not apply** means only partial coverage; **Website prevented hiding links** means styles prevented hiding and the app restored its changes. Record status/counts only, never website URLs or account content. On failure, Off must remain available and the timer must continue.

On 2026-11-13 the user first reported No matching navigation links, then reported that Reels entries no longer appear after delivery of the 0.2.1 correction. Hiding is user-reported; the installed app/rule version was not reconfirmed. The user subsequently confirmed that Off restores the entries and messages/stories remain accessible while filtering. Automatic remembered choices, broader SPA behavior, background/resume, filter accessibility and battery/performance remain pending. The Debug-only synthetic UI fixture is not evidence of Instagram's current markup.

## Remembered Instagram choices — next device check

1. With filters Active, enable **Remember for Instagram**, then close the session and start another. The page should automatically hide compatible navigation entries, with sign-in retained as managed by Instagram/WebKit.
2. Close and relaunch SocialLess: start a fresh intentional session and confirm the saved choice still applies. The timer always requires a new explicit session start.
3. Turn the master switch Off. Entries must return and the next session must remain off. Turn it back on and confirm automatic checking resumes. Repeat with the individual rule.
4. Turn Remember off: this session keeps its filter choices, but the next session starts off/locked. Alternatively, **Settings → Instagram → Forget saved website filters** removes saved choices without deleting sign-in, history or demo settings.
5. On a missing/unsupported layout, automatic mode must leave controls visible and show its status. Navigate normally; loading new compatible controls can retry through the throttled observer. Test background/resume and expiry with remembered choices.
6. Updated catalog versions must require a fresh manual check and explicit Remember choice. Authentication/consent pages stay excluded; test only when naturally encountered.

## Explore — first physical-device trial (catalog 0.3.0)

The user reported that remembered Reels stayed active after ending and reopening a session. This is not a process-termination or remembered-Off test. With this new catalog version, recheck Reels and explicitly remember the choice once; existing sign-in/history are retained.

1. Open the Instagram website feed. In Filters, check/enable Reels as before. Find **Hide Explore navigation links**, initially off/locked, and tap **Check Explore link**. Reels should stay hidden and Explore should stay visible during the check.
2. If the independent check finds a compatible entry, enable Explore. Only its navigation entry should disappear; the feed, messages/stories and separate search controls should remain usable. Search/tag/location subpaths and post links are excluded. Do not report the entire discovery feed or all recommended content removed.
3. Turn Explore off: its entry must return while Reels stays hidden. Turn Reels off with Explore on and confirm independence; master Off restores both.
4. With Remember enabled, explicitly approved Explore choices should survive a new session. Remembered Reels alone must never turn Explore on. Unknown or missing Explore layouts must not disable compatible Reels filtering; check the per-rule result and partial health.
5. If no supported Explore entry is detected, leave the rule off and report only the status. No credentials, URLs, account content or screenshots of private content are needed. Physical Explore success remains pending.

## Accessibility and layout

- VoiceOver: onboarding, platform selection, intent, countdown label/value, warning, completion, settings, error/retry and textual analytics.
- Dynamic Type accessibility sizes; small phone; portrait and landscape; light/dark; Reduce Motion.
- Verify readable contrast, no color-only statuses, minimum tap sizes and scroll reachability of primary actions.
- Confirm the countdown does not announce every refresh. Verify completion/warning navigation and reading order on device.

## Remaining real service matrix (requires user-authorized device login)

For Instagram/Facebook/TikTok: terms/embedding review → opening → permitted login → feed → available official friends/following navigation → same-site/back → redirect/popup/custom-scheme failure → no silent escape → expiration → clear login data. Never type credentials into a native SocialLess form or share them with the developer. Do not bypass browser restrictions or CAPTCHA.

Confirm that blocked embedded documents do not replace the whole website with an error. Exact blank/srcdoc child frames must work; top-level external links, new windows and downloads stay blocked. With an existing page, dismiss the link notice and continue browsing; after a process crash or before the first page loads, a blocked navigation must retain the recoverable error flow.

Cross-domain sign-in failures are expected under the strict policy; record the needed origin and review before proposing an exception. Failure must leave offline functionality usable. Do not invent selectors or populate Verified statuses without observation.

## Deferred Screen Time QA

Before implementation: entitlement, code signing and personal/individual authorization on a physical iPhone. Later test denied/revoked access, selected tokens only, disable restrictions, app termination/reboot/time-zone/DST. Never claim selective changes to another app.



## Following import and feed pilot — physical device gate

1. Request only Followers and following from the correct Instagram account's export, JSON format, all-time range. Unzip in Files. Do not send the export to the developer or attach personal data to test reports.
2. In SocialLess Settings → Instagram → Import following list, choose following.json. Verify the preview count/sample locally; Cancel must preserve the prior list. Save/Replace only if correct. ZIP, HTML, followers-array, malformed, empty and oversized files must not replace saved data. File picker cancellation should leave data unchanged.
3. Force close/reopen SocialLess: list count/date persist. No automatic filter activation. Import from both On My iPhone and a downloaded iCloud Drive file; unavailable/undownloaded files must fail clearly without data loss.
4. Start an Instagram website session → Filters → Only imported accounts. On the home feed, verify an imported author stays and an identifiable non-imported author hides. Unrecognized/collaborative posts must remain visible with honest health. Report only status/behavior, never personal handles, exports or page content.
5. Turn Off: hidden posts return without reload. Reels/Explore navigation filtering remains independently reversible. Open messages/stories/search/profile/auth: no feed mutations there. Go home and check recovery. Verify dynamic scroll, recycled authors, pause/resume, expiry and close.
6. Replace/delete the list during a session: feed filter turns Off and posts restore. Deleting must preserve login, session history, navigation preferences and original export. Reopen app to confirm deletion. Changing Instagram accounts requires a matching import; automatic account association is not implemented.
7. Test light/dark, large text, VoiceOver, long list performance and minimum supported iOS. No real-site filtering or file-provider behavior is validated by synthetic fixtures.


### Retry after 0 hidden / 7 unrecognized feed report

Install the corrected build; the saved following list is preserved. In an Instagram website session, enable Only imported accounts again (session-only). Record only health and Hidden posts / Unrecognized counts. Check actual imported-author posts remain, recognizable non-imported-author posts and labeled sponsored cards hide, unknown/collaborative cards remain, and Off restores immediately. Check dynamic scroll/recycled authors, navigation, pause/resume and expiry. Labels are currently English/Spanish candidate badges only; unfamiliar/ad posts can remain if the layout/badge cannot be recognized. Do not send account names, screenshots of private content, raw DOM, exports or URLs as diagnostics. A nonzero hidden count alone does not establish correctness.

## Strict feed and video gate — 2026-11-14

On updated iPhone build: imported accounts filter On should hide recognized non-imported and unknown-author candidate cards without blank-height gaps; inspect allowed cards, count changes and Off restoration. Unknown counts now represent hidden candidates, not visible exceptions. Unsupported non-article layouts remain an open limitation. Check three website platforms with filters Off and On: scrolling over a video must not start playback or native fullscreen; deliberate tap should play inline; pause, scroll away/back, background/resume, new document and expiry must behave correctly. Check video controls, custom play overlays, stories, messages and VoiceOver; autoplay changes must not bypass session termination. No physical result inferred from simulator DOM-event tests.

## Finite-feed device gate — 2026-11-14

With Only imported accounts On, scroll until Instagram adds a batch of rejected/unknown cards. Confirm no content flash, end screen appears once, the live spinner/feed disappears, and countdown keeps decreasing. Try again should load home with filtering still On and login retained; another rejected batch may end again. A mixed batch with a matched author must not end. Test slow loading, recycled nodes, background/resume while pending and ended, switching filter Off before the end, ending session on the screen and timer expiry while ended. No Back/foreground callback may revive a completed session. VoiceOver and large text must reach both actions. Initial loaded posts alone do not trigger this new-batch boundary. Record actual device/build results; simulator DOM fixtures do not establish current Instagram pagination compatibility.

## User-reported stability confirmation — 2026-11-14

The user confirmed that all four requested checks work: Try again retains login and feed filtering; switching the filter Off restores posts; timer expiry ends the session even on No more matching posts; closing/reopening the app and accessing messages/stories work. Prior reports separately confirm removal of hidden-post spaces, prevention of automatic reel playback and operation of the finite-feed boundary. Record these as user-reported device results, using the previously supplied iPhone 13 Pro / iOS 27.2 context; exact installed build and current device/OS were not reconfirmed. No credentials, social content, handles or URLs were requested or stored.

This closes the requested basic stability retry. Keep integrations Experimental: exhaustive author/ad detection, false positives, slow/recycled pagination, deliberate custom video controls, accessibility, large text/dark mode and wider OS/device coverage remain open. No runtime changes or new tests in this documentation-only update; previous actual build/test results remain recorded below.


## Stories filter pilot — physical gate

Instagram website → Filters → Experimental · Stories → Filter stories. Confirm Off by default and independent of feed/nav choices. Without a list check recognizable ads only; with the correct imported list check followed-account stories remain, outside-list accounts and labeled ads show Story hidden. Check native home action, Off restoration, switching route/owner/ad in an existing viewer, pause/resume, replacement/deletion, new session, expiry and preserved login. Initial load/unsupported viewer structures may expose ads; record unsupported health rather than assuming success. Check captions/account names that resemble ad labels do not falsely hide, highlight/DM/auth/home boundaries remain untouched, and no automatic story advance happens. Verify VoiceOver/text size/dark mode and video controls/no autoplay. Report only aggregate health and behavior; do not collect personal story content or URLs.

## Strict Stories retry — 2026-11-16

Use the already saved following list; turn Filter stories On in a new updated-build session. Verify identifiable followed stories remain readable, sponsored/non-imported stories are covered, and unrecognized authors show Story hidden · author not confirmed. Check an ad inserted between stories without a route change, profile/header names conflicting with the route, late author loading and layouts without semantic headers. Off must restore; home action, feed/nav filters, login, timer expiry and no-autoplay must continue working. Record only aggregate status and behavior; no private content/handles/URLs needed. Unsupported routes/highlights/iframes and transient false positives remain limitations. User's 2026-11-16 report establishes ads passing the prior pilot, not success of this revision.

## Stories false-positive retry — 2026-11-16

On the updated build with Filter stories On and saved list: friend stories with display-name/avatar profile links should remain readable; unknown/ambiguous viewers must remain visible with unrecognized status. Recognized sponsored labels alone produce Sponsored story hidden; a confirmed outside-list author produces the non-imported-account reason without calling it sponsored. Test Off restoration, route recycling, ad insertion, home/expiry/login and no-autoplay. Some unidentified ads can remain visible by design; do not report this as guaranteed ad removal. User's prior report establishes all-friends overblocking and supersedes earlier strict-unknown expected behavior.

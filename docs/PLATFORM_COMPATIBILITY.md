# Platform compatibility

Last updated: 2026-11-09. App 0.1.0. Physical device/OS: **none tested**.

| Capability | Instagram | Facebook | TikTok |
|---|---|---|---|
| Local demo fixture | Implemented | Implemented | Implemented |
| Standard HTTPS home host | Implemented, experimental | Implemented, experimental | Implemented, experimental |
| Website opens on physical iPhone | Untested | Untested | Untested |
| Embedded sign-in is permitted/stable | Untested | Untested | Untested |
| Real feed available | Untested | Untested | Untested |
| Friends/following web destination | Unavailable; unverified | Unavailable; unverified | Unavailable; unverified |
| Messages/stories | Untested | Untested | Untested |
| DOM filters | Unavailable; not implemented | Unavailable; not implemented | Unavailable; not implemented |
| Cross-origin authentication | Blocked; no reviewed exceptions | Blocked; no reviewed exceptions | Blocked; no reviewed exceptions |
| Deep links/external apps | Blocked by policy | Blocked by policy | Blocked by policy |
| Native app shielding | Unavailable | Unavailable | Unavailable |

Simulator offline tests do not establish website compatibility. No social login or live-site browsing was performed during implementation.

Only `https://www.instagram.com/`, `https://www.facebook.com/` and `https://www.tiktok.com/` are standard starting URLs, not friend-only destinations. The policy permits HTTPS root and dot-delimited subdomains for the selected service, with no external exceptions. The WebKit store is ordinary and the user agent is unchanged.

## Physical-device observation template

For each new verification, record: service, feature, date, app/rule version, device, iOS, region if relevant, actual observed behavior, status (Verified/Experimental/Unavailable), reproduction and fallback. Do not include passwords, cookies, query-bearing URLs, account identifiers, feed contents or screenshots containing private messages.

`lastVerifiedAt`: null for all real-site features. Provider announcements or simulator demo success are not substitutes for device observations.


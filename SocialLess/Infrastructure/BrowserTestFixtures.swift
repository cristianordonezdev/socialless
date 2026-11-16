#if DEBUG
import Foundation

// Local, fictional HTML for native WebKit/UI tests. Never loads a live service or account.
enum BrowserTestFixtures {
    static func usesInstagramPilot(_ configuration: SessionConfiguration) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return configuration.platform == .instagram && configuration.mode == .website &&
            arguments.contains("--uitesting") && arguments.contains("--instagram-filter-fixture")
    }

    static let instagramNavigation = """
    <!doctype html><html lang="en"><head>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; form-action 'none'">
    <style>body{font:17px -apple-system;padding:20px;color:#19203a;background:#f5f7fc}nav{display:flex;gap:18px;flex-wrap:wrap}a{color:#335cdb}article{margin-top:24px;padding:18px;background:white;border-radius:16px}</style>
    </head><body>
    <h1>Synthetic navigation</h1><p>Offline test page. No real account or posts.</p>
    <nav id="navigation" aria-label="Sample navigation">
      <a id="home" href="/">Home</a><a id="reels" href="/reels/">Sample Reels</a>
      <a id="explore" href="/explore/" aria-label="Sample Explore"><svg aria-label="Explore" width="20" height="20"></svg>Sample Explore</a>
      <a id="search" href="/explore/search/">Sample Search</a>
      <a id="messages" href="/direct/inbox/">Sample Messages</a><a id="stories" href="/stories/sample/">Sample Stories</a>
    </nav>
    <article id="post"><h2>Fictional update</h2><p>This sample post stays visible.</p>
      <a id="postLink" href="/reels/">Reels mentioned in a post</a>
    </article>
    <main>
    <article id="followed-post"><header><a href="/sample_friend/">sample_friend</a></header><p>Fictional followed post</p><a href="/p/followed/"><time>Today</time></a></article>
    <article id="suggested-post"><div><a href="/sample_other/">sample_other</a></div><img width="240" height="180" alt="Fictional media"><p>Fictional suggested post</p></article>
    </main>
    </body></html>
    """

    // A synthetic alternate layout, not captured Instagram markup.
    static var instagramUnmarkedNavigation: String {
        instagramNavigation
            .replacingOccurrences(of: "<nav id=\"navigation\"", with: "<div id=\"navigation\"")
            .replacingOccurrences(of: "</nav>", with: "</div>")
            .replacingOccurrences(of: "nav{", with: "#navigation{")
            .replacingOccurrences(of: "id=\"reels\"", with: "id=\"reels\" aria-label=\"Sample Reels\"")
            .replacingOccurrences(of: ">Sample Reels</a>", with: #"><span><svg aria-label="Reels" role="img" width="24" height="24"><rect width="20" height="20" fill="currentColor"/></svg></span><span>Sample Reels</span></a>"#)
    }
}
#endif

import Foundation

struct WebNavigationPolicy {
    let platform: SocialPlatform
    func allows(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return false }
        return host == platform.domain || host.hasSuffix("." + platform.domain)
    }

    func allowsEmbeddedDocument(_ url: URL?) -> Bool {
        // Empty/srcdoc child documents are created by the already permitted website.
        // They never become exceptions for top-level navigation or new windows.
        if let address = url?.absoluteString, ["about:blank", "about:srcdoc"].contains(address) { return true }
        return allows(url)
    }
}


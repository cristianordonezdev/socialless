import Foundation

struct WebNavigationPolicy {
    let platform: SocialPlatform
    func allows(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return false }
        return host == platform.domain || host.hasSuffix("." + platform.domain)
    }
}


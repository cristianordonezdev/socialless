import XCTest
@testable import SocialLess

final class PlatformNavigationTests: XCTestCase {
    func testExactHostAndDotDelimitedSubdomains() {
        let policy = WebNavigationPolicy(platform: .instagram)
        for url in ["https://instagram.com", "https://www.instagram.com/", "https://help.instagram.com/a", "https://INSTAGRAM.COM", "https://instagram.com:443/"] {
            XCTAssertTrue(policy.allows(URL(string: url)), url)
        }
    }
    func testRejectsSpoofedHostsSchemesCredentialsAndPorts() {
        let policy = WebNavigationPolicy(platform: .instagram)
        let rejected = ["https://evilinstagram.com", "https://instagram.com.evil.test", "http://instagram.com", "javascript:alert(1)", "file:///instagram.com", "instagram://home", "data:text/html,hello", "https://instagram.com@evil.test", "https://user:secret@instagram.com", "https://instagram.com:444/", "https://facebook.com", "https://instagram.com./", "about:blank", "about:srcdoc"]
        for url in rejected { XCTAssertFalse(policy.allows(URL(string: url)), url) }
        XCTAssertFalse(policy.allows(nil))
    }
    func testPolicyIsSelectedPlatformSpecific() {
        for selected in SocialPlatform.allCases {
            for candidate in SocialPlatform.allCases {
                XCTAssertEqual(WebNavigationPolicy(platform: selected).allows(candidate.homeURL), selected == candidate)
            }
        }
    }

    func testEmbeddedBlankDocumentsDoNotBroadenTopLevelOrForeignOriginPolicy() {
        for platform in SocialPlatform.allCases {
            let policy = WebNavigationPolicy(platform: platform)
            XCTAssertTrue(policy.allowsEmbeddedDocument(URL(string: "about:blank")))
            XCTAssertTrue(policy.allowsEmbeddedDocument(URL(string: "about:srcdoc")))
            XCTAssertTrue(policy.allowsEmbeddedDocument(platform.homeURL))
            for address in ["https://outside.invalid/", "http://\(platform.domain)/", "about:blank?redirect=1",
                            "data:text/html,fixture", "javascript:void(0)", "file:///fixture.html"] {
                XCTAssertFalse(policy.allowsEmbeddedDocument(URL(string: address)))
            }
            XCTAssertFalse(policy.allowsEmbeddedDocument(nil))
        }
    }
}


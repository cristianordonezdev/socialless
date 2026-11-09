import XCTest
import WebKit
@testable import SocialLess

final class BrowserControllerTests: XCTestCase {
    @MainActor func testWebKitActuallyInvokesForeignOriginBlock() async throws {
        let configuration = try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website)
        let controller = BrowserController(configuration: configuration, canNavigate: { true })
        defer { controller.shutdown() }
        // Reserved invalid domain: the policy must cancel before network access.
        controller.webView.load(URLRequest(url: try XCTUnwrap(URL(string: "https://outside.invalid/"))))
        for _ in 0..<50 {
            if controller.message != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNotNil(controller.message, "A real WKNavigationDelegate dispatch must enforce the policy")
        XCTAssertFalse(controller.loading)
    }

    @MainActor func testDemoLoadsAllBundledFixturesWithoutPersistentWebsiteStore() async throws {
        for platform in SocialPlatform.allCases {
            let configuration = try SessionConfiguration(platform: platform, intent: .checkFriends, duration: 300, mode: .demo)
            let controller = BrowserController(configuration: configuration, canNavigate: { true })
            controller.loadHome()
            for _ in 0..<50 {
                if !controller.loading { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertNil(controller.message)
            XCTAssertFalse(controller.loading)
            XCTAssertFalse(controller.webView.configuration.websiteDataStore.isPersistent)
            let title = try await controller.webView.evaluateJavaScript("document.title") as? String
            XCTAssertEqual(title, "SocialLess offline demo")
            controller.shutdown()
            XCTAssertFalse(controller.webView.isUserInteractionEnabled)
        }
    }

    @MainActor func testTerminalSessionCannotLoadOrRetry() async throws {
        let configuration = try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .demo)
        let controller = BrowserController(configuration: configuration, canNavigate: { false })
        controller.loadHome()
        XCTAssertNil(controller.webView.url)
        XCTAssertFalse(controller.loading)
        controller.shutdown(); controller.loadHome()
        XCTAssertFalse(controller.webView.isUserInteractionEnabled)
    }
}

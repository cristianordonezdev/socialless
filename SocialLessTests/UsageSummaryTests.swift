import XCTest
@testable import SocialLess

final class UsageSummaryTests: XCTestCase {
    private func record(at date: Date, duration: Double, platform: SocialPlatform = .instagram) -> SessionSummary {
        SessionSummary(id: UUID(), platform: platform, intent: .checkFriends, mode: .demo, startedAt: date,
                       endedAt: date.addingTimeInterval(duration), activeDurationSeconds: duration, endReason: .userEnded)
    }
    func testDayAndPlatformGroupingUsesCalendarAndExcludesOlderRecords() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Mexico_City"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let old = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: now))
        let usage = UsageSummary(sessions: [record(at: now, duration: 60), record(at: now, duration: 120, platform: .facebook), record(at: yesterday, duration: 30), record(at: old, duration: 999)], calendar: calendar)
        XCTAssertEqual(usage.sessions(on: now).count, 2)
        XCTAssertEqual(usage.days(ending: now).count, 7)
        XCTAssertEqual(usage.days(ending: now).last?.seconds, 180)
        XCTAssertEqual(usage.platformTotals(ending: now)[.instagram], 90)
        XCTAssertEqual(usage.platformTotals(ending: now)[.facebook], 120)
        XCTAssertEqual(usage.days(ending: now).reduce(0) { $0 + $1.seconds }, 210)
    }
    func testMidnightSessionBelongsToStartDayAndDSTProducesSevenDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59)))
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let usage = UsageSummary(sessions: [record(at: start, duration: 300)], calendar: calendar)
        XCTAssertEqual(usage.sessions(on: start).count, 1)
        XCTAssertEqual(usage.sessions(on: next).count, 0)
        XCTAssertEqual(Set(usage.days(ending: next).map(\.date)).count, 7)
        XCTAssertEqual(usage.days(ending: next).reduce(0) { $0 + $1.seconds }, 300)
    }
    func testEmptyUsageAndFormatting() {
        let usage = UsageSummary(sessions: [])
        XCTAssertEqual(usage.days(ending: .now).count, 7)
        XCTAssertTrue(usage.days(ending: .now, count: 0).isEmpty)
        XCTAssertEqual(usage.days(ending: .now).reduce(0) { $0 + $1.seconds }, 0)
        XCTAssertEqual(TimeLabel.countdown(60.1), "01:01")
        XCTAssertEqual(TimeLabel.countdown(-1), "00:00")
    }
}


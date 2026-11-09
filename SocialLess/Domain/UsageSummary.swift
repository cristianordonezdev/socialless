import Foundation

struct DailyUsage: Identifiable {
    let date: Date
    let seconds: TimeInterval
    let count: Int
    var id: Date { date }
}

struct UsageSummary {
    let sessions: [SessionSummary]
    let calendar: Calendar
    init(sessions: [SessionSummary], calendar: Calendar = .autoupdatingCurrent) {
        self.sessions = sessions; self.calendar = calendar
    }
    /// Entire session attributed to its start day in the user's current calendar/time zone.
    func sessions(on date: Date) -> [SessionSummary] {
        sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }
    func days(ending date: Date, count: Int = 7) -> [DailyUsage] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let records = sessions(on: day)
            return DailyUsage(date: day, seconds: Self.total(records), count: records.count)
        }
    }
    func platformTotals(ending date: Date) -> [SocialPlatform: TimeInterval] {
        guard let start = days(ending: date).first?.date,
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return [:] }
        return Dictionary(grouping: sessions.filter { $0.startedAt >= start && $0.startedAt < end }, by: \.platform)
            .mapValues(Self.total)
    }
    static func total(_ sessions: [SessionSummary]) -> TimeInterval {
        sessions.reduce(0) { $0 + max(0, $1.activeDurationSeconds) }
    }
}


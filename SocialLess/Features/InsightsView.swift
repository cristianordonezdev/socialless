import SwiftUI
import Charts

struct InsightsView: View {
    @Bindable var container: AppContainer
    @State private var includeDemo = true
    var body: some View {
        let records = container.sessions.filter { includeDemo || $0.mode != .demo }
        let usage = UsageSummary(sessions: records)
        let days = usage.days(ending: .now)
        let week = days.reduce(0) { $0 + $1.seconds }
        let previousDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -7, to: .now) ?? .now
        let previous = usage.days(ending: previousDate).reduce(0) { $0 + $1.seconds }
        List {
            Section {
                Text("A little perspective.").font(.title2.bold())
                Text("Notice your time. Choose what comes next.").foregroundStyle(.secondary)
                Toggle("Include offline demos", isOn: $includeDemo)
            }
            Section("Last 7 days") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TimeLabel.duration(week)).font(.largeTitle.bold())
                        Text("\(days.reduce(0) { $0 + $1.count }) intentional sessions").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Chart(days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.seconds / 60))
                        .foregroundStyle(Theme.accent).cornerRadius(4)
                }.frame(height: 150).accessibilityHidden(true)
                ForEach(days) { day in
                    LabeledContent(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), value: TimeLabel.duration(day.seconds))
                        .font(.subheadline)
                }
                Text("Previous 7 days: \(TimeLabel.duration(previous))").font(.footnote).foregroundStyle(.secondary)
                Text("Your weekly intention: \(container.settings.weeklyGoalMinutes) minutes. This is a guide, not a restriction.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("By platform · last 7 days") {
                ForEach(SocialPlatform.allCases) { platform in
                    LabeledContent(platform.title, value: TimeLabel.duration(usage.platformTotals(ending: .now)[platform] ?? 0))
                }
            }
            Section("Session history") {
                if records.isEmpty { Text("Your next check-in can start here. Completed sessions will appear when history is enabled.").foregroundStyle(.secondary) }
                ForEach(records) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(session.platform.title).font(.headline); Spacer(); Text(TimeLabel.duration(session.activeDurationSeconds)).monospacedDigit() }
                        Text(session.intent.title).font(.subheadline)
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        Text(session.endReason.title + (session.mode == .demo ? " · Demo" : "")).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            Section {
                Footnote(text: "Only SocialLess active time is counted, not usage in native apps or other browsers. Sessions are assigned to their start day in your current time zone. An interrupted session may omit time since its last successful checkpoint.")
            }
        }.navigationTitle("Insights").onAppear { container.refreshHistory() }
    }
}


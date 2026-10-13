import Foundation

// MARK: - FeedWindow — WHEN the standing feed block runs (Jack, 2026-10-08).
//
// "I want there to be a schedule that blocks apps so they are not indefinite,
// so take that from Opal." Onboarding v2 collected the answer; this turns it
// into something the system can enforce.
//
// ⭐ ONE TRUTH, TWO READERS. The app asks `contains(_:)` before it ever puts the
// junk shield up, and the DeviceActivityMonitor extension (a separate process,
// woken by the system at the window's edges) decodes the same JSON from the App
// Group and asks the same question. Its copy of the logic lives in
// BrainDietMonitor/DeviceActivityMonitorExtension.swift (`MonitorFeedWindow`);
// keep the two `contains` bodies identical.
//
// ⭐ OVERNIGHT WINDOWS ARE SPLIT AT MIDNIGHT. A repeating DeviceActivitySchedule
// is one interval inside a day, so 10pm to 8am becomes [10pm, 11:59pm] on the
// start day and [12am, 8am] on the next. The monitor does not clear the shield
// at 11:59pm because it re-asks `contains(now + 2 min)`, which is still true.

struct FeedWindow: Codable, Equatable, Sendable {
    var schedule: FeedSchedule
    /// Minutes after midnight.
    var start: Int
    var end: Int
    /// Days the window STARTS on. 1 = Sunday … 7 = Saturday (Calendar.weekday).
    var weekdays: [Int]
    /// "Protect my first hour" (Jack, 2026-10-12): the wake time, in minutes
    /// after midnight. The feeds stay shut for the hour after it, every day,
    /// ON TOP of the schedule. Nil = off. Optional so older saved JSON decodes.
    var firstHourFrom: Int? = nil

    static let firstHourMinutes = 60

    static let always = FeedWindow(schedule: .always, start: 0, end: 0, weekdays: Array(1...7))

    /// Resolve a saved answer to concrete times. Presets ignore the custom fields.
    init(schedule: FeedSchedule, customStart: Int, customEnd: Int, customWeekdays: [Int]) {
        switch schedule {
        case .always:       self = .always
        case .weekdays9to5: self.init(schedule: schedule, start: 9 * 60, end: 17 * 60, weekdays: [2, 3, 4, 5, 6])
        case .nights:       self.init(schedule: schedule, start: 22 * 60, end: 8 * 60, weekdays: Array(1...7))
        case .custom:
            let days = customWeekdays.filter { (1...7).contains($0) }
            self.init(schedule: schedule,
                      start: ((customStart % 1440) + 1440) % 1440,
                      end: ((customEnd % 1440) + 1440) % 1440,
                      weekdays: days.isEmpty ? Array(1...7) : Array(Set(days)).sorted())
        }
    }

    init(schedule: FeedSchedule, start: Int, end: Int, weekdays: [Int]) {
        self.schedule = schedule
        self.start = start
        self.end = end
        self.weekdays = weekdays
    }

    var isAlways: Bool { schedule == .always }
    /// Ends on the following day (10pm to 8am). Equal times = a full 24 hours.
    var crossesMidnight: Bool { end <= start }

    // MARK: Is the block on at this moment?

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        if isAlways { return true }
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let w = c.weekday ?? 1
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if let f = firstHourFrom, (m - f + 1440) % 1440 < Self.firstHourMinutes { return true }
        if !crossesMidnight { return weekdays.contains(w) && m >= start && m < end }
        let previous = w == 1 ? 7 : w - 1
        return (weekdays.contains(w) && m >= start) || (weekdays.contains(previous) && m < end)
    }

    /// The next moment the block switches on, or nil for Always.
    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        guard !isAlways else { return nil }
        let today = calendar.startOfDay(for: date)
        var best: Date?
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let at = calendar.date(byAdding: .minute, value: start, to: day),
                  at > date
            else { continue }
            best = at
            break
        }
        if let f = firstHourFrom {
            for offset in 0...1 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let at = calendar.date(byAdding: .minute, value: f, to: day),
                      at > date
                else { continue }
                if best == nil || at < best! { best = at }
                break
            }
        }
        return best
    }

    // MARK: DeviceActivity segments

    struct Segment: Equatable {
        let name: String
        let start: DateComponents
        let end: DateComponents
    }

    /// Apple's floor for a DeviceActivitySchedule interval.
    static let minimumMinutes = 15
    private static let lastMinute = 23 * 60 + 59

    /// Repeating intervals that together cover the window. Daily schedules use
    /// no weekday component (fewer activities against the system's cap); a
    /// subset of days pins each interval to its weekday. At most 14.
    var segments: [Segment] {
        guard !isAlways else { return [] }
        let everyDay = Set(weekdays) == Set(1...7)
        var ranges: [(day: Int?, from: Int, to: Int)] = []
        let days: [Int?] = everyDay ? [nil] : weekdays.map { Optional($0) }
        for d in days {
            if crossesMidnight {
                ranges.append((d, start, Self.lastMinute))
                if end > 0 { ranges.append((d.map { $0 == 7 ? 1 : $0 + 1 }, 0, end)) }
            } else {
                ranges.append((d, start, end))
            }
        }
        return ranges.enumerated().compactMap { i, r in
            // Shorter than Apple's minimum would throw; the app's own
            // `contains` check still covers those few minutes on foreground.
            guard r.to - r.from >= Self.minimumMinutes else { return nil }
            var s = DateComponents(hour: r.from / 60, minute: r.from % 60)
            var e = DateComponents(hour: r.to / 60, minute: r.to % 60)
            s.weekday = r.day
            e.weekday = r.day
            return Segment(name: "\(BlockingConfig.feedActivityPrefix)\(i)", start: s, end: e)
        } + firstHourSegments
    }

    /// The first hour, every day. Still under the feed prefix, so the monitor
    /// treats its edges like any other and asks `contains`.
    private var firstHourSegments: [Segment] {
        guard let f = firstHourFrom else { return [] }
        let from = ((f % 1440) + 1440) % 1440
        let to = min(from + Self.firstHourMinutes, Self.lastMinute)
        guard to - from >= Self.minimumMinutes else { return [] }
        return [Segment(name: "\(BlockingConfig.feedActivityPrefix)firstHour",
                        start: DateComponents(hour: from / 60, minute: from % 60),
                        end: DateComponents(hour: to / 60, minute: to % 60))]
    }

    // MARK: Words

    /// "Weekdays · 9am–5pm", "Every night · 10pm–8am", "Always".
    var summary: String {
        if isAlways { return String(localized: "Always on") }
        let base = "\(daysLabel) · \(Self.clock(start))–\(Self.clock(end))"
        return firstHourFrom == nil ? base : "\(base) · " + String(localized: "First hour")
    }

    /// "7:30–8:30am".
    static func firstHourRange(_ from: Int) -> String {
        "\(clock(from).replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: ""))–\(clock((from + firstHourMinutes) % 1440))"
    }

    private var daysLabel: String {
        let set = Set(weekdays)
        if set == Set(1...7) {
            return crossesMidnight ? String(localized: "Every night") : String(localized: "Every day")
        }
        if set == Set(2...6) { return String(localized: "Weekdays") }
        if set == [1, 7] { return String(localized: "Weekends") }
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }   // Monday first
            .map { symbols[$0 - 1] }
            .joined(separator: ", ")
    }

    /// "Open until 9am", "Open until tomorrow 10pm", "Open until Monday 9am".
    func openUntilLine(now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let next = nextStart(after: now, calendar: calendar) else { return nil }
        let at = calendar.dateComponents([.hour, .minute], from: next)
        let time = Self.clock((at.hour ?? 0) * 60 + (at.minute ?? 0))
        if calendar.isDate(next, inSameDayAs: now) { return String(localized: "Open until \(time)") }
        if calendar.isDateInTomorrow(next) { return String(localized: "Open until tomorrow \(time)") }
        let day = calendar.weekdaySymbols[calendar.component(.weekday, from: next) - 1]
        return String(localized: "Open until \(day) \(time)")
    }

    /// 540 → "9am", 1290 → "9:30pm", 0 → "12am".
    static func clock(_ minutes: Int) -> String {
        let h24 = (minutes / 60) % 24
        let m = minutes % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        let suffix = h24 < 12 ? "am" : "pm"
        return m == 0 ? "\(h12)\(suffix)" : String(format: "%d:%02d%@", h12, m, suffix)
    }
}

extension FeedSchedule: Codable {}

extension UserProfile {
    /// The saved answer as an enforceable window.
    var feedWindow: FeedWindow {
        var w = FeedWindow(schedule: feedSchedule, customStart: feedCustomStart,
                           customEnd: feedCustomEnd, customWeekdays: feedCustomWeekdays)
        if firstHourBlock { w.firstHourFrom = wakeMinutes >= 0 ? wakeMinutes : 450 }
        return w
    }
}

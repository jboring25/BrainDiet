import Foundation

// MARK: - DayUsage — one day of AUTOMATIC usage on the user's flagged apps.
//
// The app is now fully automatic (product-spec-v2): reclaimed time is DERIVED
// from Screen Time / DeviceActivity, not from anything the user logs. This is
// the atomic unit the engine reads — one value per day: how many minutes the
// user spent on their flagged ("junk") apps that day.
//
// Reclaimed(day) = max(0, baseline − flaggedMinutes(day)), where `baseline` is
// the onboarding self-assessment of daily short-form use. The baseline is the
// personal reference point the whole product is measured against.

struct DayUsage: Identifiable, Equatable {
    var id: Date { day }
    /// Start-of-day this usage belongs to.
    let day: Date
    /// Minutes spent on the flagged apps that day (from DeviceActivity when
    /// entitled; seeded in DEBUG otherwise).
    let flaggedMinutes: Int
    /// True once real data exists for this day (an entitled build reporting a
    /// value, or a seeded day). Days with no data don't count toward totals.
    let hasData: Bool
    /// Per-nutrition-class minutes on the MONITORED apps that day — the raw signal
    /// behind "Today's Mental Diet" (spec-v2.1). Automatic: DeviceActivity accrues
    /// per-category meter events; seeded in DEBUG. Empty when uncategorized.
    var categoryMinutes: [AppCategory: Int]

    init(day: Date, flaggedMinutes: Int, hasData: Bool,
         categoryMinutes: [AppCategory: Int] = [:]) {
        self.day = day
        self.flaggedMinutes = flaggedMinutes
        self.hasData = hasData
        self.categoryMinutes = categoryMinutes
    }

    /// Total monitored minutes across all categories (the panel's denominator).
    var monitoredMinutes: Int { categoryMinutes.values.reduce(0, +) }

    static func empty(_ day: Date) -> DayUsage {
        DayUsage(day: day, flaggedMinutes: 0, hasData: false)
    }
}

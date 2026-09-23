import SwiftUI

// MARK: - JunkBudget — the plan's slop ALLOWANCE vs. today's junk minutes.
//
// Noom's permission mechanic: junk isn't forbidden, it's budgeted. The plan's
// junkCapMinutes is the daily allowance; spent is today's junk-category minutes
// from the automatic engine. Never red, never shame — over budget just gets a
// fresh-tray line.
//
// (The "Today's Plate" bar-chart label that used to live here was replaced by
// the signature BDMealTray — Components/BDMealTray.swift — 2026-07-06. This
// value type is its data companion and also drives the slop-voice trigger.)

struct JunkBudget: Equatable {
    let spentMinutes: Int
    let budgetMinutes: Int

    var isOver: Bool { spentMinutes > budgetMinutes }
    /// 0…1 spent fraction (clamped) for the slim budget bar.
    var fraction: Double {
        min(1, Double(spentMinutes) / Double(max(1, budgetMinutes)))
    }
}

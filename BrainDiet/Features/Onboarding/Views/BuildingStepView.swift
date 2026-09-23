import SwiftUI

// MARK: - Step: building — the honest labor illusion (Opal mapping row 7).
//
// It IS computing their plan (the GoalPlanner runs on the VM's timed task),
// and it now PRECEDES the mirror — Opal's "Preparing report…" frames the
// mirror as computed-for-you work. Re-themed to the appetite canon
// (2026-07-18): the dark PortionBlob bento tray is gone. On the light cream
// canvas, the PLATE assembles through its real aligned states — the
// PlateEmpty → PlateMorning → PlateMidday → PlateNourished crossfade (the same
// full-color ramp as Home; never a filter) — while the copy reads the user's
// own answers back: "Reading your day… Plating your servings…". Reduce Motion:
// the plate rests at a settled state, lines still cycle.

struct BuildingStepView: View {
    @Bindable var vm: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineIndex = 0
    @State private var lineOpacity: Double = 0
    /// Drives the plate's real-state crossfade 0 → 1 across the build.
    @State private var assembly: Double = 0

    /// The domain the plan is built around, lower-cased for inline copy.
    private var primaryWord: String {
        ((vm.primaryDomain ?? vm.selectedDomains.first)?.label ?? "what matters").lowercased()
    }

    /// Whole hours the deterministic plan returns per day (0 in edge/jumped state).
    private var reclaimHours: Int { vm.makePlan().reclaimedHours }

    /// Assembly steps drawn from the user's real inputs (honest labor illusion).
    private var lines: [String] {
        var out = [
            String(localized: "Reading your day…"),
            String(localized: "Plating your servings…")
        ]
        if reclaimHours > 0 {
            out.append(String(localized: "Setting \(reclaimHours)h a day back for \(primaryWord)…"))
        } else {
            out.append(String(localized: "Setting your daily time back…"))
        }
        return out
    }

    var body: some View {
        // A tight, centered cluster — eyebrow · the assembling plate · the line.
        VStack(spacing: 0) {
            Spacer()

            Text("THIS IS YOUR BEGINNING")
                .font(.bdEyebrow)
                .kerning(3)
                .foregroundStyle(Color.bdTextSecondary)

            // The plate fills through its REAL states as the plan is computed —
            // steam arrives with the food (the layer gates itself).
            // ⭐ heroOnly (2026-07-22 UX audit): the ramp's intermediate renders
            // are different DISHES — mid-build the plate read as a "soup bowl,"
            // an unrelated meal to Welcome's hero salad. Now the SAME hero dish
            // (PlateNourished) is plated continuously; one motif, one meal.
            BDPlateMark(nourishment: assembly, steaming: assembly >= 0.5, heroOnly: true)
                .frame(width: 300)
                .padding(.vertical, Theme.Space.xl)
                .accessibilityElement()
                .accessibilityLabel("Plating your plan")

            // Single line at a time — the string is swapped only while fully faded
            // out, so two lines can NEVER overlap (no garbled "ghost" line).
            Text(lines[lineIndex])
                .font(.bdHeadline)
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .opacity(lineOpacity)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // The plate assembles across the whole build window (~2.4s).
            if reduceMotion {
                assembly = 0.66
            } else {
                withAnimation(.easeInOut(duration: 2.2).delay(0.15)) { assembly = 1 }
            }
            // Cycle copy while the plan is actually built: fade fully OUT, swap the
            // string, fade IN. Never two strings on screen at once.
            for i in lines.indices {
                if i != 0 {
                    withAnimation(.easeInOut(duration: 0.2)) { lineOpacity = 0 }
                    try? await Task.sleep(for: .milliseconds(220))
                }
                lineIndex = i
                withAnimation(.easeInOut(duration: 0.25)) { lineOpacity = 1 }
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
        .task {
            await vm.runBuildingThenMirror()
        }
    }
}

#Preview {
    ZStack { BDBackground(); BuildingStepView(vm: OnboardingViewModel()) }
}

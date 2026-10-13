import SwiftUI
import SwiftData

// MARK: - "The finish line just moved." (Jack approved 2026-10-12)
//
// design/milestone/milestone.png, frames 2 and 3. Opened by "I hit it" on
// Becoming or Home. Two shapes:
//   • a milestone was reached: check stamps in (success haptic), the stop is
//     struck, the next one lights up, the AI adds a NEW stop at the end so
//     there are always stops ahead, and the daily steps rebuild around it.
//   • the moonshot itself was reached (no stops ahead): a bigger one is
//     suggested in their voice, they type over it, the AI lays a new road.

struct FinishLineView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Kind { case milestone, moonshot }
    @State private var kind: Kind?
    @State private var stamped = false

    // Milestone shape.
    @State private var reached: Milestone?
    @State private var before: [Milestone] = []
    /// Matched by title: `Milestone.id` is not stored, so it changes on every read.
    @State private var newStopTitle: String?
    @State private var extending = true
    @State private var rebuilding = true

    // Moonshot shape.
    @State private var lastMoonshot = ""
    @State private var nextMoonshot = ""
    @State private var thinking = true
    @State private var laying = false
    @State private var roadFailed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bdBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch kind {
                    case .milestone: milestoneBody
                    case .moonshot:  moonshotBody
                    case nil:        EmptyView()
                    }
                }
                .padding(.horizontal, Theme.Space.screenX)
                .padding(.top, 36)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .sensoryFeedback(.success, trigger: stamped)
        .task { await start() }
    }

    // MARK: Start

    private func start() async {
        guard kind == nil else { return }
        if profile.isAtMoonshot {
            kind = .moonshot
            lastMoonshot = GoalSentenceText.display(profile.moonshotText)
            stamp()
            let suggestion = await FinishLineService.bigger(than: profile.moonshotText)
            withAnimation(Theme.Motion.smooth) {
                if nextMoonshot.isEmpty { nextMoonshot = suggestion ?? "" }
                thinking = false
            }
            return
        }
        kind = .milestone
        before = profile.milestones
        var road = profile.milestones
        guard let i = road.firstIndex(where: { !$0.done && !$0.isBlank }) else { dismiss(); return }
        road[i].done = true
        reached = road[i]
        profile.milestones = road
        try? modelContext.save()
        stamp()

        if let stop = await FinishLineService.extend(moonshot: profile.moonshotText,
                                                     finish: profile.finishLabel, road: road) {
            road.append(stop)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                profile.milestones = road
                newStopTitle = stop.title
            }
        }
        withAnimation(Theme.Motion.smooth) { extending = false }
        await PlanRebuild.run(profile: profile, context: modelContext)
        Log.app.info("Finish line: milestone reached, road now \(road.count, privacy: .public) stops.")
        rebuilding = false   // no crossfade: two button titles overlapped mid-fade
    }

    private func stamp() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.58).delay(0.15)) { stamped = true }
    }

    // MARK: Milestone reached

    private var milestoneBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                badge(symbol: "checkmark", fill: .bdLeafDeep)
                Spacer()
                Button("Undo") { undo() }
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .disabled(rebuilding)
                    .opacity(rebuilding ? 0.4 : 1)
            }
            eyebrow("Milestone reached", color: .bdLeaf)
            Text("You did it.\nThe finish line just moved.")
                .font(BDFont.serif(size: 32, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Text("There's always a next one. Here's the road now.")
                .font(BDFont.body(.regular, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, 6)

            road.padding(.top, 24)

            if !rebuilding, let next = profile.milestones.current {
                (Text("Your daily steps now aim at ")
                 + Text(next.title).foregroundStyle(Color.bdLeafDeep).bold()
                 + Text("."))
                    .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
    }

    /// The reached stop, every stop ahead, the new one, the moonshot.
    private var road: some View {
        let ahead = profile.milestones.filled.filter { !$0.done }
        return VStack(alignment: .leading, spacing: 9) {
            if let reached { stop(reached.title, reached.by, style: .done) }
            ForEach(Array(ahead.enumerated()), id: \.element.title) { i, m in
                stop(m.title, m.by.isEmpty ? "" : "by \(m.by)",
                     style: m.title == newStopTitle ? .new : i == 0 ? .now : .ahead)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
            if extending {
                stop(String(localized: "Finding your next stop"), "", style: .loading)
            }
            stop(profile.finishLabel, String(localized: "the moonshot"), style: .finish)
        }
        .background(alignment: .leading) {
            Rectangle().fill(Color.bdCardBorder).frame(width: 2)
                .padding(.vertical, 20).padding(.leading, 5)
        }
    }

    private enum StopStyle { case done, now, ahead, new, loading, finish }

    private func stop(_ title: String, _ trailing: String, style: StopStyle) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(style == .done || style == .now ? Color.bdLeaf
                      : style == .finish ? Color.bdTextPrimary : Color.bdBackground)
                .overlay(Circle().strokeBorder(style == .finish ? Color.bdTextPrimary : Color.bdLeaf, lineWidth: 2))
                .frame(width: 12, height: 12)
                .background(Circle().fill(style == .now ? Color.bdLeafTint : .clear).frame(width: 20, height: 20))
            HStack(spacing: 8) {
                Text(title)
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .strikethrough(style == .done, color: Color.bdSlopFaint)
                    .foregroundStyle(style == .finish ? Color.white
                                     : style == .done || style == .loading ? Color.bdTextSecondary : Color.bdTextPrimary)
                    .lineLimit(2)
                if style == .new {
                    Text("NEW")
                        .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                        .kerning(0.8)
                        .foregroundStyle(Color.bdLeaf)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.bdLeafTint, in: RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 6)
                if style == .loading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(trailing)
                        .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(style == .finish ? Color.white.opacity(0.75) : Color.bdTextSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style == .finish ? Color.bdTextPrimary
                          : style == .now ? Color.bdLeafTint
                          : style == .done ? Color.clear : Color.bdSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style == .now || style == .new || style == .loading ? Color.bdLeaf
                                  : style == .finish ? Color.bdTextPrimary : Color.bdCardBorder,
                                  style: StrokeStyle(lineWidth: 1.5,
                                                     dash: style == .new || style == .loading ? [5, 4] : []))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func undo() {
        profile.milestones = before
        try? modelContext.save()
        rebuilding = true
        Task {
            await PlanRebuild.run(profile: profile, context: modelContext)
            dismiss()
        }
    }

    // MARK: Moonshot reached

    private var moonshotBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            badge(symbol: "flag.fill", fill: .bdTextPrimary)
            eyebrow("Moonshot reached", color: .bdTextPrimary)
            Text("You did the thing you said you'd do.")
                .font(BDFont.serif(size: 32, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Text("Now dream bigger. What's your next moonshot?")
                .font(BDFont.body(.regular, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, 6)

            (Text("Last one: ") + Text(lastMoonshot).strikethrough(color: Color.bdSlopFaint))
                .font(BDFont.body(.regular, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, 22)

            TextField(thinking ? String(localized: "Thinking bigger…") : String(localized: "Your next moonshot"),
                      text: $nextMoonshot, axis: .vertical)
                .font(BDFont.serif(size: 21, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
                .lineLimit(2...5)
                .padding(16)
                .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.bdLeaf, lineWidth: 1.5))
                .padding(.top, 10)

            Text(roadFailed ? String(localized: "Couldn't lay the road just now. Try again.")
                 : String(localized: "Suggested from your last one. Type over it."))
                .font(BDFont.body(.semiBold, size: 12, relativeTo: .caption))
                .foregroundStyle(roadFailed ? Color.bdSalmonText : Color.bdLeaf)
                .padding(.top, 8)
                .opacity(thinking ? 0 : 1)
        }
    }

    private var trimmedNext: String { nextMoonshot.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func setNextMoonshot() {
        let text = trimmedNext
        laying = true
        roadFailed = false
        Task {
            let body = RoadRequest(moonshot: text, context: .init(
                timeLost: nil, whenItGets: profile.whenItGets.map(\.label), feelAfter: "", triedBefore: []))
            guard let road = await RoadService.road(body) else {
                laying = false
                roadFailed = true
                return
            }
            let domain = profile.primaryDomain ?? road.domain
            profile.moonshot = text
            profile.milestones = road.milestones
            profile.moonshotFinish = road.finish
            profile.goalWords = [domain: text]
            profile.goalShorts = road.short.isEmpty ? [:] : [domain: road.short]
            await PlanRebuild.run(profile: profile, context: modelContext)
            Log.app.info("Finish line: new moonshot set, \(road.milestones.count, privacy: .public) stops.")
            dismiss()
        }
    }

    // MARK: Pieces

    private func badge(symbol: String, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 64, height: 64)
            .overlay(Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white))
            .scaleEffect(stamped ? 1 : 0.4)
            .opacity(stamped ? 1 : 0)
            .padding(.bottom, 18)
            .accessibilityHidden(true)
    }

    private func eyebrow(_ text: LocalizedStringResource, color: Color) -> some View {
        Text(text)
            .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
            .kerning(1.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 14) {
            switch kind {
            case .milestone:
                BDPrimaryButton(title: rebuilding ? "Rebuilding your steps…" : "Go get it",
                                isEnabled: !rebuilding) { dismiss() }
            case .moonshot:
                Button("Not now") { dismiss() }
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                BDPrimaryButton(title: laying ? "Laying the road…" : "Set my next moonshot",
                                isEnabled: !laying && !thinking && trimmedNext.count >= MoonshotExamples.minLength) {
                    setNextMoonshot()
                }
            case nil:
                EmptyView()
            }
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.bottom, 12)
        .padding(.top, 16)
        .background(Color.bdBackground.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }
}

/// "I hit it" — the entry on Becoming and Home.
struct HitItButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("I hit it", systemImage: "checkmark")
                .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.bdLeafDeep, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Marks this milestone reached and shows what's next")
    }
}

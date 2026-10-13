import SwiftUI
import SwiftData
#if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
import FamilyControls
import ManagedSettings
#endif

// MARK: - In your face (Jack approved 2026-10-12, design/block-screen/ frames 3–4).
//
// Where "Go to BrainDiet" on a shield lands. The moonshot, the why and the
// next stop in their own words, then the brain line: you wire whatever you
// repeat. "Do the work" starts the step's Do it now lock. A pass is the small
// text underneath and opens ONLY the app the shield was covering, for
// `InterceptPass.windowMinutes`; the monitor puts the shield back after.
// No breathe step: Jack cut it ("I do not need the second breathe in screen").

struct InYourFaceView: View {
    let profile: UserProfile
    let focus: TodaysFocus?

    @Environment(\.dismiss) private var dismiss
    @Environment(BlockingService.self) private var blocking
    @Query private var sessions: [ProtectSession]

    @State private var passed: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_SHOW_FACE"] == "passed"
        #else
        return false
        #endif
    }()
    @State private var token: Data? = {
        #if DEBUG
        // `BD_SHOW_FACE=pass` stands in a token so the pass row can be shot.
        if ProcessInfo.processInfo.environment["BD_SHOW_FACE"] == "pass" { return Data() }
        #endif
        return FaceRequest.token
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bdBackground.ignoresSafeArea()
            if passed { passedBody } else { faceBody }
            footer
        }
        .overlay(alignment: .topTrailing) {
            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.bdBarTrack, in: Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
        .sensoryFeedback(.success, trigger: passed)
        .task {
            Log.app.info("Face shown; shield notify status: \(FaceRequest.lastNotifyStatus, privacy: .public)")
            // Someone who reached this without the banner has never been asked.
            await NotificationService.requestPermissionAfterFirstWin()
        }
    }

    // MARK: The goal

    private var faceBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("You said you'd")
                    .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bdHoneyText)

                Text(moonshotLine)
                    .font(BDFont.serif(size: 33, relativeTo: .largeTitle))
                    .foregroundStyle(Color.bdTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if let reason {
                    (Text("Because: ").foregroundStyle(Color.bdTextSecondary)
                     + Text(reason + ".").foregroundStyle(Color.bdTextPrimary).bold())
                        .font(BDFont.body(.regular, size: 15, relativeTo: .subheadline))
                        .padding(.top, 10)
                }

                if let next = profile.milestones.current {
                    HStack(spacing: 12) {
                        Circle().fill(Color.bdLeaf).frame(width: 10, height: 10)
                            .background(Circle().fill(Color.bdLeafTint).frame(width: 18, height: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.title)
                                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                                .foregroundStyle(Color.bdTextPrimary)
                            Text(next.by.isEmpty ? String(localized: "Next stop")
                                                 : String(localized: "Next stop · by \(next.by)"))
                                .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                                .foregroundStyle(Color.bdTextSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1.5))
                    .padding(.top, 18)
                }

                // ⭐ The brain line (Jack: "more about neuroplasticity").
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your brain wires whatever you repeat.")
                        .foregroundStyle(Color.bdTextPrimary)
                    Text("Scroll, and you wire the scroll. Do the work, and you wire who you said you'd be.")
                        .foregroundStyle(Color.bdSalmon)
                }
                .font(BDFont.serif(size: 22, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)

                Text(wiredLine)
                    .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary)
                    .monospacedDigit()
                    .padding(.top, 12)
            }
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.top, 56)
            .padding(.bottom, 170)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: After a pass

    private var passedBody: some View {
        VStack(spacing: 0) {
            Spacer()
            PassedAppIcon(token: token)
            Text("It's open for \(InterceptPass.windowMinutes) minutes.")
                .font(BDFont.serif(size: 28, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
            Text("Go back to it yourself.\nPass \(InterceptPass.spentToday()) of \(InterceptPass.dailyAllowance) today.")
                .font(BDFont.body(.regular, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Space.screenX)
        .transition(.opacity)
    }

    // MARK: Buttons

    private var footer: some View {
        VStack(spacing: 14) {
            Button(action: doTheWork) {
                VStack(spacing: 2) {
                    Text(passed ? "Actually, do the work" : "Do the work")
                        .font(BDFont.body(.bold, size: 17, relativeTo: .headline))
                    if let f = focus {
                        Text("\(f.step.title) · \(f.step.suggestedMinutes) min")
                            .font(BDFont.body(.regular, size: 12.5, relativeTo: .caption))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.bdLeafDeep, in: Capsule())
                .shadow(color: Color.bdLeafDeep.opacity(0.25), radius: 9, y: 6)
            }
            .buttonStyle(.plain)

            if !passed, token != nil {
                let left = InterceptPass.remainingToday()
                Button { usePass() } label: {
                    Text(left > 0 ? String(localized: "Use a pass · \(left) left today")
                                  : String(localized: "No passes left today"))
                        .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextSecondary)
                        .frame(minHeight: Theme.Size.minTouch)
                }
                .buttonStyle(.plain)
                .disabled(left == 0)
            }
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.bottom, 10)
        .padding(.top, 14)
        .background(Color.bdBackground.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    private func doTheWork() {
        guard let f = focus else { close(); return }
        let session = DoItNowSession(title: f.step.title, domainRaw: f.domain.rawValue,
                                     goalID: f.goal.id, stepID: f.step.id,
                                     minutes: f.step.suggestedMinutes)
        FaceRequest.clearToken()
        dismiss()
        // One full-screen cover at a time: the lock opens once this one is gone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { blocking.startDoItNow(session) }
    }

    private func usePass() {
        guard blocking.spendFacePass(token: token) else { return }
        FaceRequest.clearToken()
        withAnimation(Theme.Motion.smooth) { passed = true }
    }

    private func close() {
        FaceRequest.clearToken()
        dismiss()
    }

    // MARK: Words

    private var moonshotLine: String {
        let m = GoalSentenceText.display(profile.moonshotText)
        return m.isEmpty ? (focus?.goal.identityLine ?? "") : m
    }

    private var reason: String? {
        guard let d = profile.primaryDomain ?? profile.domains.first else { return nil }
        return profile.goalReasons[d]?.label
    }

    /// Lally et al. (2010): about 66 days of repetition to automatic. Counted
    /// as distinct days with any session, the same rule as Home's stat.
    private var wiredLine: String {
        let cal = Calendar.current
        let days = Set(sessions.map { cal.startOfDay(for: $0.startedAt) }).count
        let left = max(0, 66 - days)
        return left == 0
            ? String(localized: "You've done the reps. Keep it wired.")
            : String(localized: "\(left) more days of reps until it's automatic.")
    }
}

/// The real app's icon, from its token (the only way iOS shows which app).
private struct PassedAppIcon: View {
    let token: Data?
    var body: some View {
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        if let token, let app = try? JSONDecoder().decode(ApplicationToken.self, from: token) {
            Label(app).labelStyle(.iconOnly).scaleEffect(2.2).frame(width: 60, height: 60)
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }
    private var placeholder: some View {
        Image(systemName: "lock.open.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Color.bdLeafDeep)
            .frame(width: 60, height: 60)
            .background(Color.bdLeafTint, in: RoundedRectangle(cornerRadius: 14))
    }
}

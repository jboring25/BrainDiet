import SwiftUI

// MARK: - "Add something you did" — typed, in their own words (Jack approved
// 2026-10-13, design/report-typed/report.png).
//
// "I need it to be something where the user can type out exactly what they
// did and add how much time they spent on it." The activity list is gone: one
// field, one "How long?" row of chips (Other = an hours/minutes wheel), and
// Feed my brain. The AI files the text under an area in the background
// (`DomainClassifier`, server mode "classify") so Becoming counts it; the
// sheet never shows that. The typed words are kept on the session (`note`).

struct ReportSomethingSheet: View {

    /// The moonshot's goal: a report filed under its area counts toward it.
    let primaryGoal: Goal?
    let moonshot: String
    var onReport: (PlateDraggable) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_REPORT_TEXT"] ?? ""
        #else
        return ""
        #endif
    }()
    @State private var minutes: Int? = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_REPORT_MIN"].flatMap(Int.init)
        #else
        return nil
        #endif
    }()
    @State private var showOther = false
    /// The AI's filing for the text it was asked about.
    @State private var filedText = ""
    @State private var filedDomain: ActivityDomain?
    @State private var sending = false

    private static let presets = [15, 30, 45, 60, 120]

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { trimmed.count >= 2 && minutes != nil && !sending }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.bdBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What did you do?")
                            .font(BDFont.serif(size: 23, relativeTo: .title2))
                            .foregroundStyle(Color.bdTextPrimary)
                            .padding(.top, 4)
                        Text("In your own words. It counts the same as a session.")
                            .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.bdTextSecondary)
                            .padding(.top, 5)

                        TextField("Wrote the intro to my essay", text: $text, axis: .vertical)
                            .font(BDFont.serif(size: 18, relativeTo: .body))
                            .foregroundStyle(Color.bdTextPrimary)
                            .lineLimit(1...4)
                            .focused($focused)
                            .submitLabel(.done)
                            .onChange(of: text) { _, new in
                                // Return closes the keyboard instead of a new line.
                                if new.contains("\n") {
                                    text = new.replacingOccurrences(of: "\n", with: "")
                                    focused = false
                                }
                                if text.count > 140 { text = String(text.prefix(140)) }
                            }
                            .padding(14)
                            .frame(minHeight: 56, alignment: .topLeading)
                            .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(trimmed.isEmpty ? Color.bdCardBorder : Color.bdLeaf, lineWidth: 1.5))
                            .padding(.top, 14)

                        Text("How long?")
                            .font(BDFont.body(.bold, size: 10.5, relativeTo: .caption2))
                            .kerning(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bdTextSecondary)
                            .padding(.top, 20)

                        FlowLayout(spacing: 6) {
                            ForEach(Self.presets, id: \.self) { m in
                                chip(Self.label(m), selected: minutes == m) { minutes = m }
                            }
                            chip(otherLabel, selected: minutes.map { !Self.presets.contains($0) } ?? false) {
                                focused = false
                                showOther = true
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                BDPrimaryButton(title: "Feed my brain", isEnabled: canSend) { send() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(BDFont.body(.semiBold, size: 15, relativeTo: .body))
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        // File it while they pick a time, so Feed my brain never waits.
        .task(id: trimmed) {
            let t = trimmed
            guard t.count >= 3 else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, let d = await DomainClassifier.classify(t, moonshot: moonshot) else { return }
            if t == trimmed { filedText = t; filedDomain = d }
        }
        .sheet(isPresented: $showOther) {
            OtherDurationSheet(minutes: minutes ?? 90) { minutes = $0 }
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Send

    private func send() {
        guard let mins = minutes, canSend else { return }
        sending = true
        let t = trimmed
        Task { @MainActor in
            var domain = filedText == t ? filedDomain : nil
            if domain == nil { domain = await DomainClassifier.classify(t, moonshot: moonshot, timeout: 1.5) }
            let d = domain ?? DomainClassifier.guess(t)
                ?? primaryGoal.flatMap { ActivityDomain(rawValue: $0.domain) } ?? .building
            let goal = primaryGoal.flatMap { ActivityDomain(rawValue: $0.domain) == d ? $0 : nil }
            onReport(PlateDraggable(title: t, subtitle: Self.label(mins),
                                    activityID: d.activityID, goalID: goal?.id, stepID: nil,
                                    minutes: mins, icon: .leaf, tint: d.tint, ink: .bdTextPrimary,
                                    note: t))
            Log.app.info("Typed report filed as \(d.rawValue, privacy: .public) · \(mins, privacy: .public)m")
            dismiss()
        }
    }

    // MARK: Pieces

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(selected ? Color.white : Color.bdTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.bdLeafDeep : Color.bdSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.bdLeafDeep : Color.bdCardBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var otherLabel: String {
        guard let m = minutes, !Self.presets.contains(m) else { return String(localized: "Other") }
        return Self.label(m)
    }

    /// 45 → "45m", 60 → "1h", 90 → "1h 30m".
    static func label(_ m: Int) -> String {
        if m < 60 { return "\(m)m" }
        return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
    }
}

/// "Other": an hours + minutes wheel.
private struct OtherDurationSheet: View {
    @State private var hours: Int
    @State private var mins: Int
    let onDone: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    init(minutes: Int, onDone: @escaping (Int) -> Void) {
        _hours = State(initialValue: minutes / 60)
        _mins = State(initialValue: (minutes % 60) / 5 * 5)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Text("How long?")
                .font(BDFont.serif(size: 22, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(0..<13) { Text("\($0) h").tag($0) }
                }
                Picker("Minutes", selection: $mins) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 170)
            BDPrimaryButton(title: "Done", isEnabled: hours * 60 + mins > 0) {
                onDone(hours * 60 + mins)
                dismiss()
            }
            .padding(.horizontal, Theme.Space.screenX)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.bdBackground.ignoresSafeArea())
    }
}

// MARK: - DomainClassifier — which area a typed report belongs to.

enum DomainClassifier {

    private struct Request: Encodable {
        var mode = "classify"
        let text: String
        let moonshot: String
    }
    private struct Response: Decodable, Sendable { let domain: String? }

    /// The plan server's filing, or nil (offline, slow, unsure).
    static func classify(_ text: String, moonshot: String, timeout: TimeInterval = 4) async -> ActivityDomain? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_PLAN_STUB"] == "1" { return guess(text) ?? .building }
        #endif
        guard let url = RoadService.url,
              let body = try? JSONEncoder().encode(Request(text: text, moonshot: moonshot)) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios-1", forHTTPHeaderField: "X-BD-Client")
        req.httpBody = body
        let request = req
        return await withTaskGroup(of: ActivityDomain?.self) { group in
            group.addTask {
                guard let (data, resp) = try? await URLSession.shared.data(for: request),
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let r = try? JSONDecoder().decode(Response.self, from: data)
                else { return nil }
                return r.domain.flatMap(ActivityDomain.init(rawValue:))
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Offline fallback: a few obvious words. Nil when nothing matches.
    static func guess(_ text: String) -> ActivityDomain? {
        let t = text.lowercased()
        let table: [(ActivityDomain, [String])] = [
            (.reading, ["read", "book", "chapter", "pages"]),
            (.fitness, ["gym", "lift", "run", "workout", "pushup", "squat", "sport", "swim"]),
            (.writing, ["wrote", "write", "essay", "journal", "blog"]),
            (.learning, ["study", "studied", "class", "course", "homework", "lecture", "learn"]),
            (.music, ["guitar", "piano", "sing", "song", "music"]),
            (.outdoors, ["walk", "hike", "outside"]),
            (.creating, ["draw", "paint", "design", "edit", "film", "photo"]),
            (.social, ["call", "friend", "family", "mom", "dad"]),
            (.mindful, ["meditat", "pray", "breath", "yoga"]),
            (.building, ["code", "coded", "app", "ship", "build", "email", "startup", "business"]),
        ]
        return table.first { $0.1.contains(where: t.contains) }?.0
    }
}

import SwiftUI

private let roadmapSuccess = Color(red: 0.12, green: 0.55, blue: 0.36)

// MARK: - Create card

/// Offered once per workspace when a curated roadmap exists and none has been created yet.
struct RoadmapCreateCard: View {
    let template: RoadmapTemplate
    let onCreate: () -> Void

    @State private var isBuilding = false
    @State private var statusIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                Text("ROADMAP")
                    .tracking(0.8)
            }
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(PathlyDashboardTheme.softAccent)

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text(template.summary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(template.stages.enumerated()), id: \.element.id) { index, stage in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Image(systemName: stage.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PathlyDashboardTheme.accent)
                                .frame(width: 30, height: 30)
                                .background(PathlyDashboardTheme.elevatedSurface, in: Circle())
                            if index < template.stages.count - 1 {
                                Rectangle()
                                    .fill(PathlyDashboardTheme.border)
                                    .frame(width: 2, height: 18)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.title)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(PathlyDashboardTheme.primaryText)
                            Text(stage.dateLabel)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        }
                        .padding(.top, 5)
                    }
                }
            }

            if isBuilding {
                HStack(spacing: 10) {
                    ProgressView().tint(PathlyDashboardTheme.accent)
                    Text(template.buildingStatuses[min(statusIndex, template.buildingStatuses.count - 1)])
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .contentTransition(.opacity)
                        .id(statusIndex)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(PathlyDashboardTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            } else {
                Button(action: build) {
                    Label("Build my roadmap", systemImage: "wand.and.stars")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
            }

            RoadmapSourceLine(template: template)
        }
        .padding(18)
        .pathlyDashboardCard()
    }

    private func build() {
        PathlyHaptics.impact()
        withAnimation(.easeInOut(duration: 0.2)) { isBuilding = true }
        Task {
            for index in template.buildingStatuses.indices {
                withAnimation(.easeInOut(duration: 0.2)) { statusIndex = index }
                try? await Task.sleep(for: .milliseconds(650))
            }
            PathlyHaptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { onCreate() }
        }
    }
}

private struct RoadmapSourceLine: View {
    let template: RoadmapTemplate

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal")
            Text("Pathly guide · checked \(template.checkedDate) · ")
            + Text(template.sources.map(\.title).joined(separator: ", "))
        }
        .font(.system(.caption2, design: .rounded, weight: .medium))
        .foregroundStyle(PathlyDashboardTheme.secondaryText)
    }
}

// MARK: - Roadmap

struct RoadmapSection: View {
    @EnvironmentObject private var workspaceStore: OpportunityWorkspaceStore
    @EnvironmentObject private var dataStore: DataStore

    let template: RoadmapTemplate
    let progress: RoadmapProgress
    let opportunityID: String

    @State private var expandedStageIDs: Set<String> = []
    @State private var hasSetInitialExpansion = false
    @State private var celebration: String?

    private var activeStageIndex: Int? {
        template.stages.firstIndex { stage in
            stage.steps.contains { !progress.completedStepIDs.contains($0.id) }
        }
    }

    private var nextStep: (stage: RoadmapStage, step: RoadmapStep)? {
        guard let index = activeStageIndex else { return nil }
        let stage = template.stages[index]
        guard let step = stage.steps.first(where: { !progress.completedStepIDs.contains($0.id) }) else { return nil }
        return (stage, step)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            overview
            if let celebration {
                celebrationBanner(celebration)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let nextStep {
                upNext(nextStep.stage, nextStep.step)
            }
            VStack(spacing: 0) {
                ForEach(Array(template.stages.enumerated()), id: \.element.id) { index, stage in
                    stageRow(stage, index: index)
                }
            }
        }
        .onAppear {
            guard !hasSetInitialExpansion else { return }
            hasSetInitialExpansion = true
            if let index = activeStageIndex { expandedStageIDs = [template.stages[index].id] }
        }
    }

    // MARK: Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ROADMAP")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                    Text(template.title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                }
                Spacer()
                Text("\(progress.completedCount)/\(progress.stepIDs.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: Double(progress.completedCount), total: Double(max(progress.stepIDs.count, 1)))
                .tint(PathlyDashboardTheme.accent)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack(spacing: 6) {
                ForEach(Array(template.stages.enumerated()), id: \.element.id) { index, stage in
                    timelineChip(stage, index: index)
                }
            }

            if let index = activeStageIndex, let countdown = countdown(to: template.stages[index].date) {
                Label {
                    Text("\(template.stages[index].title) ") + Text(countdown).bold()
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.primaryText)
            }

            RoadmapSourceLine(template: template)
        }
        .padding(18)
        .pathlyDashboardCard()
    }

    private func timelineChip(_ stage: RoadmapStage, index: Int) -> some View {
        let state = stageState(index)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: state == .done ? "checkmark.circle.fill" : stage.symbol)
                    .font(.caption2.weight(.bold))
                Text(shortDate(stage))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .lineLimit(1)
            }
            Text(stage.kicker.components(separatedBy: " · ").last ?? stage.kicker)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(state == .active ? Color.white : (state == .done ? roadmapSuccess : PathlyDashboardTheme.secondaryText))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            state == .active ? PathlyDashboardTheme.accent : PathlyDashboardTheme.elevatedSurface,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }

    // MARK: Up next

    private func upNext(_ stage: RoadmapStage, _ step: RoadmapStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Up next", systemImage: "arrow.turn.down.right")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)
            // Two reserved lines keep "Mark done" in place as titles change.
            Text(step.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)
                .lineLimit(2, reservesSpace: true)
            Text(stage.kicker)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
            Button {
                toggle(step, in: stage)
            } label: {
                Label("Mark done", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PathlyDashboardTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Stages

    private enum StageState { case done, active, upcoming }

    private func stageState(_ index: Int) -> StageState {
        let stage = template.stages[index]
        if stage.steps.allSatisfy({ progress.completedStepIDs.contains($0.id) }) { return .done }
        return index == activeStageIndex ? .active : .upcoming
    }

    private func stageRow(_ stage: RoadmapStage, index: Int) -> some View {
        let state = stageState(index)
        let isExpanded = expandedStageIDs.contains(stage.id)
        let isLast = index == template.stages.count - 1

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(state == .upcoming ? PathlyDashboardTheme.elevatedSurface : (state == .done ? roadmapSuccess : PathlyDashboardTheme.accent))
                    Image(systemName: state == .done ? "checkmark" : (state == .upcoming ? "lock.fill" : stage.symbol))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(state == .upcoming ? PathlyDashboardTheme.secondaryText : Color.white)
                }
                .frame(width: 34, height: 34)
                .padding(.top, 16)

                if !isLast {
                    Rectangle()
                        .fill(state == .done ? roadmapSuccess.opacity(0.5) : PathlyDashboardTheme.border)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        if isExpanded { expandedStageIDs.remove(stage.id) } else { expandedStageIDs.insert(stage.id) }
                    }
                    PathlyHaptics.selection()
                } label: {
                    stageHeader(stage, state: state, isExpanded: isExpanded, index: index)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    stageBody(stage)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .pathlyDashboardCard(cornerRadius: 20)
            .opacity(state == .upcoming && !isExpanded ? 0.78 : 1)
            .padding(.bottom, isLast ? 0 : 12)
        }
        // Lets the connector line stretch to the card's height.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stageHeader(_ stage: RoadmapStage, state: StageState, isExpanded: Bool, index: Int) -> some View {
        let completed = stage.steps.filter { progress.completedStepIDs.contains($0.id) }.count
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.kicker.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(state == .done ? roadmapSuccess : PathlyDashboardTheme.softAccent)
                Text(stage.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stage.dateLabel)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                Text(state == .upcoming && index > 0 && completed == 0
                     ? "Unlocks after \(template.stages[index - 1].kicker.components(separatedBy: " · ").first ?? "the last stage")"
                     : "\(completed) of \(stage.steps.count) done")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(state == .done ? roadmapSuccess : PathlyDashboardTheme.secondaryText.opacity(0.85))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }

    private func stageBody(_ stage: RoadmapStage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stage.outcome)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(stage.steps) { step in
                    stepRow(step, in: stage)
                }
            }

            if let gate = stage.gate {
                Label(gate, systemImage: "arrow.down.forward.circle")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 13))
            }

            HStack(spacing: 8) {
                if let id = stage.opportunityID, let opportunity = dataStore.opportunity(id: id) {
                    NavigationLink {
                        OpportunityDetailView(
                            opportunity: opportunity,
                            organization: opportunity.organizationID.flatMap { orgID in
                                dataStore.organizations.first { $0.id == orgID }
                            }
                        )
                    } label: {
                        Label("Event details", systemImage: "doc.text.magnifyingglass")
                            .roadmapPillStyle(filled: false)
                    }
                    .buttonStyle(.plain)
                }
                if let link = stage.link {
                    Link(destination: link.url) {
                        HStack(spacing: 5) {
                            Text(link.title)
                            Image(systemName: "arrow.up.right")
                        }
                        .roadmapPillStyle(filled: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stepRow(_ step: RoadmapStep, in stage: RoadmapStage) -> some View {
        let isDone = progress.completedStepIDs.contains(step.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                toggle(step, in: stage)
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? roadmapSuccess : PathlyDashboardTheme.secondaryText.opacity(0.6))
                        .symbolEffect(.bounce, value: isDone)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(isDone ? PathlyDashboardTheme.secondaryText : PathlyDashboardTheme.primaryText)
                            .strikethrough(isDone)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = step.detail, !isDone {
                            Text(detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(step.title), \(isDone ? "done" : "not done")")

            if let help = step.help, !isDone {
                RoadmapHelpView(help: help)
                    .padding(.leading, 34)
            }
        }
        .padding(.vertical, 3)
    }

    private func celebrationBanner(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.title3.weight(.bold))
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(roadmapSuccess, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Actions

    private func toggle(_ step: RoadmapStep, in stage: RoadmapStage) {
        let wasDone = progress.completedStepIDs.contains(step.id)
        let remainingInStage = stage.steps.filter { !progress.completedStepIDs.contains($0.id) }.count
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            workspaceStore.toggleRoadmapStep(step.id, for: opportunityID)
        }
        guard !wasDone, remainingInStage == 1,
              let index = template.stages.firstIndex(where: { $0.id == stage.id }) else {
            PathlyHaptics.selection()
            return
        }

        // Finishing a stage: celebrate, collapse it, open the next one.
        PathlyHaptics.success()
        let next = index + 1 < template.stages.count ? template.stages[index + 1] : nil
        let message = next.map { "\(stage.kicker.components(separatedBy: " · ").first ?? "Stage") complete. \($0.title) is next." }
            ?? "Roadmap complete. Nice work."
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            celebration = message
            expandedStageIDs.remove(stage.id)
            if let next { expandedStageIDs.insert(next.id) }
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut(duration: 0.3)) {
                if celebration == message { celebration = nil }
            }
        }
    }

    // MARK: Dates

    private func shortDate(_ stage: RoadmapStage) -> String {
        guard let date = stage.date else { return "TBA" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func countdown(to date: Date?) -> String? {
        guard let date else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return nil
        case 0: return "is today"
        case 1: return "is tomorrow"
        default: return "in \(days) days"
        }
    }
}

// MARK: - Step help

/// Predefined guidance for one step, revealed with short status lines.
struct RoadmapHelpView: View {
    let help: RoadmapHelp

    private enum Phase { case idle, working(Int), answered }
    @State private var phase: Phase = .idle

    var body: some View {
        switch phase {
        case .idle:
            Button(action: ask) {
                Label(help.prompt, systemImage: "sparkles")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(PathlyDashboardTheme.accent.opacity(0.09), in: Capsule())
            }
            .buttonStyle(.plain)
        case .working(let index):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0...index, id: \.self) { item in
                    HStack(spacing: 8) {
                        if item < index {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(roadmapSuccess)
                        } else {
                            ProgressView().controlSize(.small).tint(PathlyDashboardTheme.accent)
                        }
                        Text(help.statuses[item])
                    }
                    .transition(.opacity)
                }
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(PathlyDashboardTheme.secondaryText)
        case .answered:
            VStack(alignment: .leading, spacing: 9) {
                Label("Pathly", systemImage: "sparkles")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                ForEach(help.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(PathlyDashboardTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(tip)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(PathlyDashboardTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let footnote = help.footnote {
                    Text(footnote)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PathlyDashboardTheme.elevatedSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
    }

    private func ask() {
        PathlyHaptics.selection()
        Task {
            for index in help.statuses.indices {
                withAnimation(.easeInOut(duration: 0.2)) { phase = .working(index) }
                try? await Task.sleep(for: .milliseconds(700))
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .answered }
        }
    }
}

private extension View {
    func roadmapPillStyle(filled: Bool) -> some View {
        self
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(filled ? Color.white : PathlyDashboardTheme.softAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(
                filled ? PathlyDashboardTheme.accent : PathlyDashboardTheme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

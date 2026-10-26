import SwiftUI

struct OpportunityWorkspaceView: View {
    @EnvironmentObject private var workspaceStore: OpportunityWorkspaceStore
    let opportunity: Opportunity
    let organization: Organization?
    @State private var newTaskTitle = ""
    @FocusState private var isEditing: Bool

    private var workspace: OpportunityWorkspace? {
        workspaceStore.workspace(for: opportunity.id)
    }

    private var roadmapTemplate: RoadmapTemplate? {
        RoadmapTemplate.template(for: opportunity.id)
    }

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            if let workspace {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        workspaceHeader(workspace)
                        if let template = roadmapTemplate {
                            if let roadmap = workspace.roadmap {
                                RoadmapSection(template: template, progress: roadmap, opportunityID: opportunity.id)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                RoadmapCreateCard(template: template) {
                                    workspaceStore.createRoadmap(from: template, for: opportunity.id)
                                }
                            }
                        }
                        progressSection(workspace)
                        if workspace.roadmap == nil {
                            nextStepSection(workspace)
                        }
                        checklistSection(workspace)
                        notesSection(workspace)
                        officialInformationSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            } else {
                ProgressView("Preparing your workspace…")
                    .tint(PathlyDashboardTheme.accent)
            }
        }
        .navigationTitle("My workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditing = false }
            }
        }
        .task(id: opportunity.id) {
            workspaceStore.startWorkspace(for: opportunity)
        }
    }

    @ViewBuilder
    private func nextStepSection(_ workspace: OpportunityWorkspace) -> some View {
        if workspace.status != .finished, let task = workspace.tasks.first(where: { !$0.isCompleted }) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Up next", systemImage: "arrow.turn.down.right")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                Text(task.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        workspaceStore.toggleTask(task.id, for: opportunity.id)
                    }
                    PathlyHaptics.selection()
                } label: {
                    Label("Mark step complete", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(PathlyDashboardTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func workspaceHeader(_ workspace: OpportunityWorkspace) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PathlyDashboardTheme.elevatedSurface)

                    if let assetName = opportunity.imageAssetName ?? organization?.logoAssetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    } else {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 29, weight: .semibold))
                            .foregroundStyle(PathlyDashboardTheme.accent)
                    }
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 5) {
                    Text("WORKSPACE")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(PathlyDashboardTheme.softAccent)

                    Text(opportunity.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let organization {
                        Text(organization.name)
                            .font(.subheadline)
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    }
                }

                Spacer(minLength: 0)
            }

            NavigationLink {
                OpportunityDetailView(opportunity: opportunity, organization: organization)
            } label: {
                HStack {
                    Label("View opportunity details", systemImage: "doc.text.magnifyingglass")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .pathlyDashboardCard()
    }

    private func progressSection(_ workspace: OpportunityWorkspace) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("Progress")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Spacer()
                Text("\(workspace.completedStepCount) of \(workspace.totalStepCount) steps")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }

            ProgressView(value: workspace.progress)
                .tint(statusColor(workspace.status))
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            HStack(spacing: 8) {
                ForEach(OpportunityWorkStatus.allCases) { status in
                    statusButton(status, selectedStatus: workspace.status)
                }
            }
        }
        .padding(18)
        .pathlyDashboardCard(cornerRadius: 20)
    }

    private func statusButton(
        _ status: OpportunityWorkStatus,
        selectedStatus: OpportunityWorkStatus
    ) -> some View {
        let isSelected = status == selectedStatus
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                workspaceStore.setStatus(status, for: opportunity.id)
            }
            PathlyHaptics.selection()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: status.symbol)
                    .font(.subheadline.weight(.bold))
                Text(status.title)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? Color.white : PathlyDashboardTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                isSelected ? statusColor(status) : PathlyDashboardTheme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func checklistSection(_ workspace: OpportunityWorkspace) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(workspace.roadmap == nil ? "My checklist" : "My own steps", systemImage: "checklist")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)

            Text("Your personal plan, not official requirements. Add or remove steps as you go.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(workspace.tasks) { task in
                HStack(alignment: .top, spacing: 11) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            workspaceStore.toggleTask(task.id, for: opportunity.id)
                        }
                        PathlyHaptics.selection()
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(
                                task.isCompleted
                                    ? PathlyDashboardTheme.accent
                                    : PathlyDashboardTheme.secondaryText.opacity(0.65)
                            )
                    Text(task.title)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(
                            task.isCompleted
                                ? PathlyDashboardTheme.secondaryText
                                : PathlyDashboardTheme.primaryText
                        )
                        .strikethrough(task.isCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(task.title), \(task.isCompleted ? "completed" : "not completed")")
                    .accessibilityHint(task.isCompleted ? "Mark incomplete" : "Mark complete")

                    Menu {
                        Button("Delete task", systemImage: "trash", role: .destructive) {
                            workspaceStore.removeTask(task.id, from: opportunity.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Task options")
                }
                .padding(.vertical, 2)
            }

            Divider().overlay(PathlyDashboardTheme.border)

            HStack(spacing: 10) {
                TextField("Add your own task", text: $newTaskTitle)
                    .focused($isEditing)
                    .font(.system(.subheadline, design: .rounded))
                    .submitLabel(.done)
                    .onSubmit(addTask)

                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(PathlyDashboardTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add task")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 13))
        }
        .padding(18)
        .pathlyDashboardCard(cornerRadius: 20)
    }

    private var officialInformationSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 13) {
            officialFact("Status", opportunity.status.rawValue)
            officialFact("Deadline", opportunity.deadline?.formatted(date: .long, time: .omitted))
            officialFact("Eligibility", opportunity.eligibilityNotes)

            Link(destination: opportunity.officialURL) {
                HStack {
                    Label("Check the official page", systemImage: "safari")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            }
            .padding(.top, 14)
        } label: {
            Label("Official information", systemImage: "checkmark.seal")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)
        }
        .tint(PathlyDashboardTheme.accent)
        .padding(18)
        .pathlyDashboardCard(cornerRadius: 20)
    }

    private func officialFact(_ label: String, _ value: String?) -> some View {
        let displayValue = value.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Pathly does not have this information yet."
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)
            Text(displayValue)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notesSection(_ workspace: OpportunityWorkspace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("My notes", systemImage: "note.text")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)

            TextEditor(
                text: Binding(
                    get: { workspace.notes },
                    set: { workspaceStore.updateNotes($0, for: opportunity.id) }
                )
            )
            .focused($isEditing)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(PathlyDashboardTheme.primaryText)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .padding(10)
            .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                if workspace.notes.isEmpty {
                    Text("Save ideas, links, questions, or what you need to work on next.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText.opacity(0.75))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(18)
        .pathlyDashboardCard(cornerRadius: 20)
    }

    private func addTask() {
        workspaceStore.addTask(title: newTaskTitle, to: opportunity.id)
        newTaskTitle = ""
        PathlyHaptics.selection()
    }

    private func statusColor(_ status: OpportunityWorkStatus) -> Color {
        switch status {
        case .notStarted: PathlyDashboardTheme.secondaryText
        case .inProgress: PathlyDashboardTheme.accent
        case .finished: Color(red: 0.12, green: 0.55, blue: 0.36)
        }
    }
}

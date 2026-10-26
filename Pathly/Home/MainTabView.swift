import SwiftUI

enum MainTab: Int {
    case home
    case explore
    case map
    case saved
}

struct MainTabView: View {
    let resetOnboarding: () -> Void
    @State private var selectedTab: MainTab

    init(resetOnboarding: @escaping () -> Void) {
        self.resetOnboarding = resetOnboarding

        #if DEBUG
        let debugTab = ProcessInfo.processInfo.environment["PATHLY_TAB"]
            .flatMap(Int.init)
            .flatMap(MainTab.init(rawValue:))
        _selectedTab = State(initialValue: debugTab ?? .home)
        #else
        _selectedTab = State(initialValue: .home)
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                resetOnboarding: resetOnboarding,
                showExplore: { selectedTab = .explore },
                showMap: { selectedTab = .map }
            )
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(MainTab.home)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "safari.fill") }
                .tag(MainTab.explore)

            MapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(MainTab.map)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(MainTab.saved)
        }
        .tint(PathlyDashboardTheme.accent)
        .toolbarBackground(PathlyDashboardTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .preferredColorScheme(.light)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(width: 104, height: 104)
                    .background(PathlyDashboardTheme.accent.opacity(0.1), in: Circle())
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(24)
        }
    }
}

struct SavedView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var savedItems: SavedItemsStore
    @EnvironmentObject private var workspaceStore: OpportunityWorkspaceStore
    @State private var selectedStatus: OpportunityWorkStatus?

    private var organizationsByID: [String: Organization] {
        Dictionary(uniqueKeysWithValues: dataStore.organizations.map { ($0.id, $0) })
    }

    private var savedResults: [ExploreResult] {
        let opportunities = Dictionary(uniqueKeysWithValues: dataStore.opportunities.map { ($0.id, $0) })
        let places = Dictionary(uniqueKeysWithValues: dataStore.places.map { ($0.id, $0) })
        let organizations = organizationsByID

        return savedItems.itemIDs.compactMap { id in
            if let opportunity = opportunities[id] {
                return .opportunity(
                    opportunity,
                    opportunity.organizationID.flatMap { organizations[$0] }
                )
            }
            if let place = places[id] {
                return .place(
                    place,
                    place.organizationID.flatMap { organizations[$0] }
                )
            }
            return nil
        }
    }

    private var savedOpportunities: [Opportunity] {
        let opportunities = Dictionary(uniqueKeysWithValues: dataStore.opportunities.map { ($0.id, $0) })
        return savedItems.itemIDs.compactMap { opportunities[$0] }
    }

    private func count(for status: OpportunityWorkStatus) -> Int {
        savedOpportunities.lazy.filter { opportunity in
            (workspaceStore.workspace(for: opportunity.id)?.status ?? .notStarted) == status
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PathlyDashboardBackground()

                if savedResults.isEmpty {
                    ContentUnavailableView(
                        "Nothing Saved Yet",
                        systemImage: "bookmark",
                        description: Text("Save opportunities and places from Explore or their detail pages to find them here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            savedSummary

                            if !savedOpportunities.isEmpty {
                                workspaceSummary
                            }

                            if let selectedStatus, count(for: selectedStatus) == 0 {
                                ContentUnavailableView(
                                    "No \(selectedStatus.title.lowercased()) opportunities",
                                    systemImage: selectedStatus.symbol,
                                    description: Text("Choose another status above to see your saved projects.")
                                )
                            }

                            ForEach(savedResults.filter { result in
                                guard let selectedStatus else { return true }
                                guard case .opportunity(let opportunity, _) = result else { return false }
                                return (workspaceStore.workspace(for: opportunity.id)?.status ?? .notStarted) == selectedStatus
                            }) { result in
                                switch result {
                                case .opportunity(let opportunity, let organization):
                                    SavedOpportunityTrackerCard(
                                        opportunity: opportunity,
                                        organization: organization
                                    )
                                case .place:
                                    ExploreResultLink(result: result)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var savedSummary: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(savedResults.count.formatted()) saved")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
            Spacer()
            if !savedOpportunities.isEmpty {
                Text("\(savedOpportunities.count.formatted()) to work on")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
            }
        }
    }

    private var workspaceSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Your next steps", systemImage: "flag.checkered")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text(selectedStatus == nil ? "Turn a saved idea into something you do." : "Tap the selected status again to show all saved items.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }

            HStack(spacing: 8) {
                ForEach(OpportunityWorkStatus.allCases) { status in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                        PathlyHaptics.selection()
                    } label: {
                    VStack(spacing: 5) {
                        Text(count(for: status).formatted())
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PathlyDashboardTheme.primaryText)
                        Text(status.title)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(
                        workStatusColor(status).opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(
                            selectedStatus == status ? workStatusColor(status) : .clear, lineWidth: 1.5
                        )
                    }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(count(for: status)) \(status.title) opportunities")
                    .accessibilityAddTraits(selectedStatus == status ? .isSelected : [])
                }
            }
        }
        .padding(17)
        .pathlyDashboardCard(cornerRadius: 20)
    }
}

private struct SavedOpportunityTrackerCard: View {
    @EnvironmentObject private var workspaceStore: OpportunityWorkspaceStore
    let opportunity: Opportunity
    let organization: Organization?

    private var workspace: OpportunityWorkspace? {
        workspaceStore.workspace(for: opportunity.id)
    }

    private var status: OpportunityWorkStatus {
        workspace?.status ?? .notStarted
    }

    private var actionTitle: String {
        if workspace?.roadmap == nil, RoadmapTemplate.template(for: opportunity.id) != nil {
            return "Start my roadmap"
        }
        return switch status {
        case .notStarted: workspace == nil ? "Start working" : "Continue working"
        case .inProgress: "Continue working"
        case .finished: "Review workspace"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ExploreResultLink(result: .opportunity(opportunity, organization), showsSurface: false)

            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Label(status.title, systemImage: status.symbol)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(workStatusColor(status))

                    Spacer()

                    if let workspace {
                        Text("\(workspace.completedStepCount) of \(workspace.totalStepCount) steps")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    } else {
                        Text("Ready when you are")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    }
                }

                ProgressView(value: workspace?.progress ?? 0)
                    .tint(workStatusColor(status))

                NavigationLink {
                    OpportunityWorkspaceView(
                        opportunity: opportunity,
                        organization: organization
                    )
                } label: {
                    HStack {
                        Text(actionTitle)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 13))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .pathlyDashboardCard(cornerRadius: 22)
    }
}

private func workStatusColor(_ status: OpportunityWorkStatus) -> Color {
    switch status {
    case .notStarted: PathlyDashboardTheme.secondaryText
    case .inProgress: PathlyDashboardTheme.accent
    case .finished: Color(red: 0.12, green: 0.55, blue: 0.36)
    }
}

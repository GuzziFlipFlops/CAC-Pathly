import CoreLocation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var profileStore: OnboardingStore
    @EnvironmentObject private var savedItems: SavedItemsStore
    @EnvironmentObject private var feedbackStore: RecommendationFeedbackStore
    @EnvironmentObject private var discoveryStore: PathlyDiscoveryStore
    @EnvironmentObject private var workspaceStore: OpportunityWorkspaceStore

    let resetOnboarding: () -> Void
    let showExplore: () -> Void
    let showMap: () -> Void

    @StateObject private var locationService = LocationService()
    @State private var recommendationIDs: [String] = []
    @State private var refreshID = UUID()
    @State private var hasMarkedInitialRecommendations = false
    @State private var showsDebugPathlyAI = false
    #if DEBUG
    @AppStorage(GuidedDemoSequence.settingsKey) private var guidedDemoEnabled = true
    @State private var demoSequence = GuidedDemoSequence()
    @State private var demoMessage: String?
    #endif

    private let engine = RecommendationEngine()

    private var profile: UserProfile { profileStore.profile }

    private var homeQuery: RecommendationQuery {
        var query = discoveryStore.recommendationQuery
        #if DEBUG
        if guidedDemoEnabled { query.excludedIDs.formUnion(demoSequence.excludedHomeIDs) }
        #endif
        return query
    }

    private var organizationsByID: [String: Organization] {
        Dictionary(uniqueKeysWithValues: dataStore.organizations.map { ($0.id, $0) })
    }

    private var savedWorkspaceOpportunity: Opportunity? {
        let opportunitiesByID = Dictionary(
            uniqueKeysWithValues: dataStore.opportunities.map { ($0.id, $0) }
        )
        let savedOpportunities = savedItems.itemIDs.compactMap { opportunitiesByID[$0] }
        return savedOpportunities.first {
            workspaceStore.workspace(for: $0.id)?.status == .inProgress
        } ?? savedOpportunities.first {
            workspaceStore.workspace(for: $0.id)?.status != .finished
        } ?? savedOpportunities.first
    }

    private var rankedRecommendations: [OpportunityRecommendation] {
        var query = homeQuery
        query.limit = 4
        let ranked = engine.recommendations(
            from: dataStore.opportunities,
            profile: profile,
            query: query,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
        guard !recommendationIDs.isEmpty else { return ranked }
        let byID = Dictionary(uniqueKeysWithValues: rankedCatalog.map { ($0.id, $0) })
        let selected = recommendationIDs.compactMap { byID[$0] }
        return selected.isEmpty ? ranked : selected
    }

    private var rankedCatalog: [OpportunityRecommendation] {
        var query = homeQuery
        query.limit = dataStore.opportunities.count
        return engine.recommendations(
            from: dataStore.opportunities,
            profile: profile,
            query: query,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
    }

    private var deadlines: [OpportunityRecommendation] {
        let results = engine.deadlineRecommendations(
            from: dataStore.opportunities,
            profile: profile,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
        #if DEBUG
        if guidedDemoEnabled { return results.filter { !demoSequence.excludedHomeIDs.contains($0.id) } }
        #endif
        return results
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let latitude = locationService.latitude, let longitude = locationService.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var nearbyPlaces: [PlaceRecommendation] {
        engine.nearbyPlaces(
            from: dataStore.places,
            profile: profile,
            coordinateOverride: currentCoordinate
        )
    }

    private var greeting: String {
        let base: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        if let firstName = profile.firstName { return base + ", " + firstName }
        return base
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PathlyDashboardBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        header
                        savedWorkspaceIsland
                        pathlyAICard
                        temporaryDiscoveryBanner
                        recommendationsSection
                        deadlinesSection
                        nearYouSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsDebugPathlyAI) {
                PathlyAIChatView()
            }
            .onAppear {
                if recommendationIDs.isEmpty { recommendationIDs = rankedRecommendations.map(\.id) }
                if !hasMarkedInitialRecommendations, !recommendationIDs.isEmpty {
                    feedbackStore.markShown(recommendationIDs)
                    hasMarkedInitialRecommendations = true
                }
                #if DEBUG
                if ProcessInfo.processInfo.environment["PATHLY_OPEN_AI"] == "1" {
                    showsDebugPathlyAI = true
                }
                #endif
            }
            .onChange(of: profileStore.profile) { _, _ in
                withAnimation(.easeInOut(duration: 0.22)) {
                    recommendationIDs = []
                    refreshID = UUID()
                }
            }
            .onChange(of: discoveryStore.revision) { _, _ in
                withAnimation(.easeInOut(duration: 0.22)) {
                    recommendationIDs = []
                    refreshID = UUID()
                }
            }
            #if DEBUG
            .onChange(of: guidedDemoEnabled) { _, _ in
                demoSequence = GuidedDemoSequence()
                demoMessage = nil
                recommendationIDs = []
                refreshID = UUID()
            }
            #endif
        }
    }

    @ViewBuilder
    private var savedWorkspaceIsland: some View {
        if let opportunity = savedWorkspaceOpportunity {
            let organization = opportunity.organizationID.flatMap { organizationsByID[$0] }
            let workspace = workspaceStore.workspace(for: opportunity.id)
            let status = workspace?.status ?? .notStarted

            NavigationLink {
                OpportunityWorkspaceView(
                    opportunity: opportunity,
                    organization: organization
                )
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(PathlyDashboardTheme.accent.opacity(0.11))
                        Image(systemName: status.symbol)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(homeWorkspaceStatusColor(status))
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 6) {
                        let template = RoadmapTemplate.template(for: opportunity.id)
                        let needsRoadmap = template != nil && workspace?.roadmap == nil
                        Text(needsRoadmap
                             ? "Build your roadmap for \(opportunity.name)"
                             : homeWorkspaceAction(status, opportunityName: opportunity.name))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PathlyDashboardTheme.primaryText)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if needsRoadmap, let template {
                                Text("\(template.stages.count) stages · Ready to begin")
                            } else {
                                Text(status.title)
                                if let workspace {
                                    Text("·")
                                    Text("\(workspace.completedStepCount) of \(workspace.totalStepCount) steps")
                                } else {
                                    Text("· Ready to begin")
                                }
                            }
                        }
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                        ProgressView(value: workspace?.progress ?? 0)
                            .tint(homeWorkspaceStatusColor(status))
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PathlyDashboardTheme.accent)
                }
                .padding(15)
                .pathlyDashboardCard(cornerRadius: 21)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your opportunity progress workspace")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PATHLY")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(PathlyDashboardTheme.accent)
                Text(greeting)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text("Find your next opportunity.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }

            Spacer(minLength: 8)

            NavigationLink {
                ProfileSettingsView(resetOnboarding: resetOnboarding)
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 39))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(width: 50, height: 50)
                    .background(PathlyDashboardTheme.surface, in: Circle())
                    .overlay { Circle().stroke(PathlyDashboardTheme.border, lineWidth: 1) }
            }
            .accessibilityLabel("Profile and settings")
        }
    }

    private var pathlyAICard: some View {
        NavigationLink {
            PathlyAIChatView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 15))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ask Pathly")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PathlyDashboardTheme.primaryText)
                        Text("Tell me what you want to do.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.accent)
                }

                HStack {
                    Text("Try “What can I do near me?”")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 46)
                .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
            .pathlyDashboardCard(cornerRadius: 24)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var temporaryDiscoveryBanner: some View {
        if discoveryStore.recommendationQuery != RecommendationQuery() {
            HStack(spacing: 11) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(PathlyDashboardTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pathly AI is focusing Home")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                    Text("Temporary conversation filters are shaping these recommendations.")
                        .font(.caption)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }
                Spacer(minLength: 4)
                Button("Clear") { discoveryStore.resetTemporaryIntent() }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
            }
            .padding(13)
            .background(PathlyDashboardTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17).stroke(PathlyDashboardTheme.border, lineWidth: 1)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PathlySectionHeader(
                title: "Recommended for you",
                subtitle: "Picked for your interests and preferences"
            ) {
                Button(action: surpriseMe) {
                    Image(systemName: "dice.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(PathlyDashboardTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Surprise Me")
            }

            #if DEBUG
            if let demoMessage {
                Text(demoMessage)
                    .font(.footnote)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }
            #endif

            if rankedRecommendations.isEmpty {
                HomeEmptyCard(
                    title: "No eligible matches yet",
                    message: "Update your grade, location, or format preferences to broaden recommendations.",
                    symbol: "slider.horizontal.3"
                )
            } else {
                ForEach(rankedRecommendations) { recommendation in
                    RecommendationOpportunityCard(
                        recommendation: recommendation,
                        organization: recommendation.opportunity.organizationID.flatMap { organizationsByID[$0] }
                    )
                    .id(recommendation.id + refreshID.uuidString)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                Button("Browse everything", action: showExplore)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PathlySectionHeader(
                title: "Deadlines coming up",
                subtitle: "Plan ahead for these dates"
            )

            if deadlines.isEmpty {
                HomeEmptyCard(
                    title: "No known deadlines",
                    message: "Relevant opportunities with verified dates will appear here.",
                    symbol: "calendar"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(deadlines.enumerated()), id: \.element.id) { index, recommendation in
                        NavigationLink {
                            OpportunityDetailView(
                                opportunity: recommendation.opportunity,
                                organization: recommendation.opportunity.organizationID.flatMap { organizationsByID[$0] }
                            )
                        } label: {
                            DeadlineRow(recommendation: recommendation)
                        }
                        .buttonStyle(.plain)
                        if index < deadlines.count - 1 {
                            Divider().overlay(PathlyDashboardTheme.border).padding(.leading, 74)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .pathlyDashboardCard(cornerRadius: 20)
            }
        }
    }

    private var nearYouSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            PathlySectionHeader(
                title: "Near you",
                subtitle: profile.resolvedLocation.isEmpty ? "Add a location to see nearby resources" : profile.resolvedLocation
            ) {
                Button("View on map", action: showMap)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
            }

            if nearbyPlaces.isEmpty {
                HomeEmptyCard(
                    title: "No places in your current range",
                    message: "Add or update your location and travel distance in Settings.",
                    symbol: "mappin.and.ellipse"
                )
            } else {
                ForEach(nearbyPlaces) { recommendation in
                    RecommendationPlaceCard(
                        recommendation: recommendation,
                        organization: recommendation.place.organizationID.flatMap { organizationsByID[$0] }
                    )
                }
            }
        }
    }

    private func surpriseMe() {
        #if DEBUG
        if guidedDemoEnabled, !demoSequence.hasRevealedConrad {
            var query = discoveryStore.recommendationQuery
            query.limit = dataStore.opportunities.count
            let eligible = engine.recommendations(
                from: dataStore.opportunities, profile: profile, query: query,
                savedIDs: Set(savedItems.itemIDs), feedback: feedbackStore.snapshot
            )
            guard let picks = demoSequence.firstRoll(eligibleIDs: eligible.map(\.id)) else {
                demoMessage = "Conrad isn't available for this profile or current filters. Review your preferences before recording; eligibility is still enforced."
                return
            }
            demoMessage = nil
            withAnimation(.easeInOut(duration: 0.28)) {
                recommendationIDs = picks
                refreshID = UUID()
            }
            // Recording-only ordering must not train normal recommendation feedback.
            PathlyHaptics.impact()
            return
        }
        #endif
        let surprise = engine.surpriseRecommendations(
            from: dataStore.opportunities,
            profile: profile,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot,
            mode: discoveryStore.surpriseMode,
            count: 4
        )
        guard !surprise.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            recommendationIDs = surprise.map(\.id)
            refreshID = UUID()
        }
        feedbackStore.markShown(recommendationIDs, asSurprise: true)
        PathlyHaptics.impact()
    }
}

private func homeWorkspaceAction(
    _ status: OpportunityWorkStatus,
    opportunityName: String
) -> String {
    switch status {
    case .notStarted: "Start working on \(opportunityName)"
    case .inProgress: "Continue working on \(opportunityName)"
    case .finished: "Review \(opportunityName)"
    }
}

private func homeWorkspaceStatusColor(_ status: OpportunityWorkStatus) -> Color {
    switch status {
    case .notStarted: PathlyDashboardTheme.secondaryText
    case .inProgress: PathlyDashboardTheme.accent
    case .finished: Color(red: 0.12, green: 0.55, blue: 0.36)
    }
}

private struct DeadlineRow: View {
    let recommendation: OpportunityRecommendation

    private var daysRemaining: Int? {
        guard let deadline = recommendation.opportunity.deadline else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: deadline
        ).day
    }

    var body: some View {
        HStack(spacing: 13) {
            VStack(spacing: 1) {
                Text(daysRemaining.map(String.init) ?? "—")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                Text(daysRemaining == 1 ? "day" : "days")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }
            .frame(width: 48, height: 48)
            .background(PathlyDashboardTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.opportunity.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .lineLimit(2)
                Text(recommendation.opportunity.deadline?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.caption)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
        }
        .frame(minHeight: 70)
    }
}

private struct HomeEmptyCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.accent)
                .frame(width: 46, height: 46)
                .background(PathlyDashboardTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathlyDashboardCard(cornerRadius: 18)
    }
}

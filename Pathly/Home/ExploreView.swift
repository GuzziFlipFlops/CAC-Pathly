import SwiftUI

enum ExploreResult: Identifiable {
    case opportunity(Opportunity, Organization?)
    case place(Place, Organization?)

    var id: String {
        switch self {
        case .opportunity(let opportunity, _): "opportunity:\(opportunity.id)"
        case .place(let place, _): "place:\(place.id)"
        }
    }

    var name: String {
        switch self {
        case .opportunity(let opportunity, _): opportunity.name
        case .place(let place, _): place.name
        }
    }

    var catalogID: String {
        switch self {
        case .opportunity(let opportunity, _): opportunity.id
        case .place(let place, _): place.id
        }
    }

    /// Closed or expired opportunities and closed places.
    var hasEnded: Bool {
        switch self {
        case .opportunity(let opportunity, _): opportunity.status == .closed || opportunity.status == .expired
        case .place(let place, _): place.status == .closed
        }
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let searchableText: String
        switch self {
        case .opportunity(let opportunity, let organization):
            searchableText = [
                opportunity.name,
                organization?.name,
                opportunity.category.rawValue,
                opportunity.subcategory,
                opportunity.descriptionShort,
                opportunity.format.rawValue,
                opportunity.geographicScope.rawValue,
                opportunity.interestTags.map(\.rawValue).joined(separator: " "),
                opportunity.requiredSkills.joined(separator: " "),
                opportunity.recommendedSkills.joined(separator: " ")
            ]
            .compactMap { $0 }
            .joined(separator: " ")

        case .place(let place, let organization):
            searchableText = [
                place.name,
                organization?.name,
                place.placeType.rawValue,
                place.description,
                place.city,
                place.state,
                place.resourceTags.joined(separator: " "),
                place.interestTags.map(\.rawValue).joined(separator: " ")
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }

        let ignoredWords: Set<String> = [
            "a", "an", "and", "for", "find", "finding", "i", "in", "me", "my",
            "of", "or", "show", "something", "that", "the", "to", "want", "with"
        ]
        let terms = query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !ignoredWords.contains($0) }

        guard !terms.isEmpty else { return true }
        let normalizedSearchableText = searchableText.lowercased()
        return terms.allSatisfy { term in
            searchVariants(for: term).contains { normalizedSearchableText.contains($0) }
        }
    }

    private func searchVariants(for term: String) -> [String] {
        var variants = [term]
        if term.hasSuffix("ies"), term.count > 4 {
            variants.append(String(term.dropLast(3)) + "y")
        } else if term.hasSuffix("s"), term.count > 3 {
            variants.append(String(term.dropLast()))
        }
        return variants
    }
}

struct ExploreView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var profileStore: OnboardingStore
    @EnvironmentObject private var savedItems: SavedItemsStore
    @EnvironmentObject private var recommendationFeedback: RecommendationFeedbackStore
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var isSearching = false
    @State private var searchPhase: PathlySearchPhase = .finding
    @State private var searchRevision = 0
    @State private var selectedOpportunityCategory: OpportunityCategory?
    @State private var selectedPlaceType: PlaceType?
    @State private var selectedFormat: OpportunityFormat?
    @State private var showsAdvancedFilters = false
    @FocusState private var isSearchFocused: Bool

    private var organizationsByID: [String: Organization] {
        Dictionary(uniqueKeysWithValues: dataStore.organizations.map { ($0.id, $0) })
    }

    private var allResults: [ExploreResult] {
        let organizations = organizationsByID
        let opportunities = dataStore.opportunities.map {
            ExploreResult.opportunity($0, $0.organizationID.flatMap { organizations[$0] })
        }
        let places = dataStore.places.map {
            ExploreResult.place($0, $0.organizationID.flatMap { organizations[$0] })
        }

        // A–Z, but ended or closed records go after everything students can still act on.
        return (opportunities + places).sorted {
            let lhsEnded = $0.hasEnded, rhsEnded = $1.hasEnded
            if lhsEnded != rhsEnded { return !lhsEnded }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var personalizedRecommendations: [String: OpportunityRecommendation] {
        var query = RecommendationQuery()
        query.limit = dataStore.opportunities.count
        let recommendations = RecommendationEngine().recommendations(
            from: dataStore.opportunities,
            profile: profileStore.profile,
            query: query,
            savedIDs: Set(savedItems.itemIDs),
            feedback: recommendationFeedback.snapshot
        )
        return Dictionary(uniqueKeysWithValues: recommendations.map { ($0.id, $0) })
    }

    private var visibleResults: [ExploreResult] {
        allResults.filter { result in
            let matchesFilters: Bool
            switch result {
            case .opportunity(let opportunity, _):
                matchesFilters = selectedPlaceType == nil
                    && (selectedOpportunityCategory == nil || opportunity.category == selectedOpportunityCategory)
                    && (selectedFormat == nil || opportunity.format == selectedFormat)

            case .place(let place, _):
                matchesFilters = selectedOpportunityCategory == nil
                    && selectedFormat == nil
                    && (selectedPlaceType == nil || place.placeType == selectedPlaceType)
            }

            return matchesFilters && result.matches(submittedQuery)
        }
    }

    private var activeFilterCount: Int {
        [
            selectedOpportunityCategory != nil,
            selectedPlaceType != nil,
            selectedFormat != nil
        ].filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PathlyDashboardBackground()

                if let loadError = dataStore.loadErrorDescription {
                    ContentUnavailableView(
                        "Couldn’t Load Explore",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            hero
                            pathlySearch
                            filters

                            if isSearching {
                                PathlySearchLoadingView(
                                    query: submittedQuery,
                                    phase: searchPhase
                                )
                                .transition(.opacity)
                            } else {
                                resultSummary

                                if visibleResults.isEmpty {
                                    ContentUnavailableView.search(text: submittedQuery)
                                        .padding(.top, 12)
                                }
                                ForEach(visibleResults) { result in
                                    ExploreResultLink(
                                        result: result,
                                        contextBadges: personalizationBadges(for: result)
                                    )
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
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                #if DEBUG
                if submittedQuery.isEmpty,
                   let debugQuery = ProcessInfo.processInfo.environment["PATHLY_EXPLORE_QUERY"],
                   !debugQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    query = debugQuery
                    submitSearch()
                }
                #endif
            }
            .task(id: searchRevision) {
                guard isSearching else { return }
                do {
                    try await Task.sleep(for: .milliseconds(520))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.24)) { searchPhase = .profile }
                    try await Task.sleep(for: .milliseconds(580))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.24)) { searchPhase = .interests }
                    try await Task.sleep(for: .milliseconds(620))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.30)) { isSearching = false }
                } catch {
                    // A newer submitted search cancels the previous animation sequence.
                }
            }
            .sheet(isPresented: $showsAdvancedFilters) {
                ExploreFilterSheet(
                    selectedOpportunityCategory: $selectedOpportunityCategory,
                    selectedPlaceType: $selectedPlaceType,
                    selectedFormat: $selectedFormat
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func personalizationBadges(for result: ExploreResult) -> [String] {
        switch result {
        case .opportunity(let opportunity, _):
            guard let recommendation = personalizedRecommendations[opportunity.id],
                  let match = recommendation.labels.first,
                  match != "Eligible" else { return [] }
            return [match]
        case .place(let place, _):
            guard let state = profileStore.profile.inferredStateCode, place.state == state else { return [] }
            return ["In your state"]
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
                Text("\(allResults.count.formatted()) opportunities and places")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Find something worth pursuing.")
                    .font(.subheadline)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var pathlySearch: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .foregroundStyle(PathlyDashboardTheme.accent)

                Text("Pathly Search")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)

                Spacer()

                Text("Personalized")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.softAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(PathlyDashboardTheme.accent.opacity(0.09), in: Capsule())
            }

            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(PathlyDashboardTheme.accent)

                TextField(
                    "Search Pathly",
                    text: $query,
                    prompt: Text("An interest, event, or resource…")
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                )
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit(submitSearch)

                if !query.isEmpty || !submittedQuery.isEmpty {
                    Button(action: submitSearch) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PathlyDashboardTheme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search Pathly")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(PathlyDashboardTheme.accent.opacity(0.20), lineWidth: 1)
            }

            Text(searchGuidance)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .pathlyDashboardCard(cornerRadius: 20)
    }

    private var searchGuidance: String {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return submittedQuery.isEmpty ? "Finding opportunities suited to you." : "Search again to browse everything."
        }
        if isSearching {
            return "Finding possibilities for your next step…"
        }
        if cleanQuery != submittedQuery {
            return "Tap the arrow or press Search to explore."
        }
        return "Explore your matches below."
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Browse categories")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                Spacer()
                advancedFiltersButton
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    opportunityQuickFilter(.competition, label: "Competitions")
                    placeQuickFilter(.roboticsClub, label: "Robotics clubs")
                    placeQuickFilter(.library, label: "Libraries")
                    opportunityQuickFilter(.workshop, label: "Workshops")
                    opportunityQuickFilter(.hackathon, label: "Hackathons")
                    opportunityQuickFilter(.scholarship, label: "Scholarships")
                    placeQuickFilter(.makerspace, label: "Makerspaces")
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private var advancedFiltersButton: some View {
        Button {
            showsAdvancedFilters = true
            PathlyHaptics.selection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("Filters")
                if activeFilterCount > 0 {
                    Text(activeFilterCount.formatted())
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 21, minHeight: 21)
                        .background(PathlyDashboardTheme.accent, in: Circle())
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(PathlyDashboardTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(PathlyDashboardTheme.surface, in: Capsule())
            .overlay { Capsule().stroke(PathlyDashboardTheme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func opportunityQuickFilter(_ category: OpportunityCategory, label: String) -> some View {
        quickFilterButton(
            title: label,
            count: dataStore.opportunities.filter { $0.category == category }.count,
            isSelected: selectedOpportunityCategory == category
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOpportunityCategory = selectedOpportunityCategory == category ? nil : category
                selectedPlaceType = nil
            }
        }
    }

    private func placeQuickFilter(_ placeType: PlaceType, label: String) -> some View {
        quickFilterButton(
            title: label,
            count: dataStore.places.filter { $0.placeType == placeType }.count,
            isSelected: selectedPlaceType == placeType
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlaceType = selectedPlaceType == placeType ? nil : placeType
                selectedOpportunityCategory = nil
                selectedFormat = nil
            }
        }
    }

    private func quickFilterButton(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            PathlyHaptics.selection()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text(count.formatted())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.80) : PathlyDashboardTheme.secondaryText)
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : PathlyDashboardTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(isSelected ? PathlyDashboardTheme.softAccent : PathlyDashboardTheme.surface, in: Capsule())
            .overlay { Capsule().stroke(PathlyDashboardTheme.border, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var resultSummary: some View {
        HStack {
            Text(resultSummaryText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("A–Z")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)
        }
        .padding(.top, 2)
    }

    private var resultSummaryText: String {
        guard !submittedQuery.isEmpty else {
            return "\(visibleResults.count.formatted()) results"
        }
        let opportunityCount = visibleResults.lazy.filter {
            if case .opportunity = $0 { return true }
            return false
        }.count
        let placeCount = visibleResults.count - opportunityCount
        let noun: String
        if opportunityCount > 0, placeCount > 0 {
            noun = "opportunities and places"
        } else if placeCount > 0 {
            noun = placeCount == 1 ? "place" : "places"
        } else {
            noun = opportunityCount == 1 ? "opportunity" : "opportunities"
        }
        let verb = visibleResults.count == 1 ? "matches" : "match"
        return "We found \(visibleResults.count.formatted()) \(noun) that \(verb) “\(submittedQuery)”"
    }

    private func submitSearch() {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            isSearchFocused = false
            searchRevision += 1
            submittedQuery = ""
            isSearching = false
            return
        }
        query = cleanQuery
        submittedQuery = cleanQuery
        isSearchFocused = false
        searchPhase = .finding
        withAnimation(.easeInOut(duration: 0.22)) { isSearching = true }
        searchRevision += 1
        PathlyHaptics.impact()
    }
}

private enum PathlySearchPhase: String {
    case finding
    case profile
    case interests

    var message: String {
        switch self {
        case .finding: "Searching the Pathly catalog"
        case .profile: "Matching your personality"
        case .interests: "Matching your interests"
        }
    }

    var symbol: String {
        switch self {
        case .finding: "sparkle.magnifyingglass"
        case .profile: "person.crop.circle.badge.checkmark"
        case .interests: "heart.text.clipboard"
        }
    }
}

private struct PathlySearchLoadingView: View {
    let query: String
    let phase: PathlySearchPhase

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(PathlyDashboardTheme.accent.opacity(0.14), lineWidth: 7)
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        PathlyDashboardTheme.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 58, height: 58)
            .rotationEffect(.degrees(phase == .finding ? 0 : phase == .profile ? 120 : 240))
            .animation(.easeInOut(duration: 0.5), value: phase)
            .overlay {
                Image(systemName: phase.symbol)
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 6) {
                Text("Finding “\(query)”")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(phase.message)
                    .id(phase)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .padding(24)
        .pathlyDashboardCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finding \(query). \(phase.message).")
    }
}

struct ExploreResultLink: View {
    @EnvironmentObject private var savedItems: SavedItemsStore
    let result: ExploreResult
    var contextBadges: [String] = []
    var showsSurface = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                switch result {
                case .opportunity(let opportunity, let organization):
                    OpportunityDetailView(opportunity: opportunity, organization: organization)
                case .place(let place, let organization):
                    PlaceDetailView(place: place, organization: organization)
                }
            } label: {
                ExploreResultCard(result: result, contextBadges: contextBadges, showsSurface: showsSurface)
            }
            .buttonStyle(.plain)

            Button {
                savedItems.toggle(result.catalogID)
                PathlyHaptics.selection()
            } label: {
                Image(systemName: savedItems.contains(result.catalogID) ? "bookmark.fill" : "bookmark")
                    .font(.headline)
                    .foregroundStyle(
                        savedItems.contains(result.catalogID)
                            ? PathlyDashboardTheme.accent
                            : PathlyDashboardTheme.secondaryText
                    )
                    .frame(width: 44, height: 44)
                    .background(PathlyDashboardTheme.surface.opacity(0.94), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(
                savedItems.contains(result.catalogID)
                    ? "Remove \(result.name) from Saved"
                    : "Save \(result.name)"
            )
        }
    }
}

private struct ExploreFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedOpportunityCategory: OpportunityCategory?
    @Binding var selectedPlaceType: PlaceType?
    @Binding var selectedFormat: OpportunityFormat?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterSection("Opportunity categories") {
                        ForEach(OpportunityCategory.allCases, id: \.self) { category in
                            sheetFilterChip(category.rawValue, isSelected: selectedOpportunityCategory == category) {
                                selectedOpportunityCategory = selectedOpportunityCategory == category ? nil : category
                                selectedPlaceType = nil
                            }
                        }
                    }

                    filterSection("Place categories") {
                        ForEach(PlaceType.allCases, id: \.self) { placeType in
                            sheetFilterChip(placeType.rawValue, isSelected: selectedPlaceType == placeType) {
                                selectedPlaceType = selectedPlaceType == placeType ? nil : placeType
                                selectedOpportunityCategory = nil
                                selectedFormat = nil
                            }
                        }
                    }

                    filterSection("Opportunity format") {
                        ForEach(OpportunityFormat.allCases, id: \.self) { format in
                            sheetFilterChip(format.rawValue, isSelected: selectedFormat == format) {
                                selectedFormat = selectedFormat == format ? nil : format
                                selectedPlaceType = nil
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PathlyDashboardTheme.background)
            .navigationTitle("Filter Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedOpportunityCategory = nil
                        selectedPlaceType = nil
                        selectedFormat = nil
                        PathlyHaptics.selection()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func filterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)

            FlowLayout(spacing: 8) { content() }
        }
    }

    private func sheetFilterChip(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            PathlyHaptics.selection()
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : PathlyDashboardTheme.primaryText)
                .padding(.horizontal, 13)
                .frame(minHeight: 40)
                .background(isSelected ? PathlyDashboardTheme.accent : PathlyDashboardTheme.surface, in: Capsule())
                .overlay { Capsule().stroke(PathlyDashboardTheme.border, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
    }
}

struct ExploreResultCard: View {
    let result: ExploreResult
    var contextBadges: [String] = []
    var showsSurface = true

    var body: some View {
        if showsSurface {
            content.pathlyDashboardCard(cornerRadius: 20)
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .opportunity(let opportunity, let organization):
            opportunityCard(opportunity, organization: organization)
        case .place(let place, let organization):
            placeCard(place, organization: organization)
        }
    }

    private func opportunityCard(_ opportunity: Opportunity, organization: Organization?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
            ExploreArtwork(
                assetName: opportunity.imageAssetName ?? organization?.logoAssetName,
                symbol: opportunity.category.symbol
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(opportunity.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let organization {
                    Text(organization.name)
                        .font(.caption)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 32)
            }

                FlowLayout(spacing: 6) {
                    ForEach(Array(contextBadges.prefix(2)), id: \.self) { badge in
                        ExploreBadge(title: badge, emphasized: true)
                    }
                    ExploreBadge(title: opportunity.status.rawValue)
                }

                Text(opportunity.descriptionShort)
                    .font(.subheadline)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    .lineLimit(2)

                FlowLayout(spacing: 12) {
                    Label(opportunity.category.rawValue, systemImage: "square.grid.2x2")
                    Label(opportunity.format.rawValue, systemImage: opportunity.format.symbol)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)

                if let deadline = opportunity.deadline {
                    Label("Deadline \(deadline.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func placeCard(_ place: Place, organization: Organization?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
            ExploreArtwork(
                assetName: place.imageAssetName ?? place.placeType.categoryAssetName,
                symbol: place.placeType.symbol,
                isFullBleed: true
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(place.placeType.rawValue)
                        .font(.caption)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 32)
            }

            if !contextBadges.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(contextBadges.prefix(2)), id: \.self) { badge in
                        ExploreBadge(title: badge, emphasized: true)
                    }
                }
            }

                if let description = place.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .lineLimit(2)
                }

                FlowLayout(spacing: 12) {
                    Label(place.locationLabel, systemImage: "location")
                    if place.freeAccess == true {
                        Label("Free access", systemImage: "checkmark.circle")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ExploreArtwork: View {
    let assetName: String?
    let symbol: String
    var isFullBleed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PathlyDashboardTheme.accent.opacity(0.16),
                            PathlyDashboardTheme.elevatedSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let assetName {
                if isFullBleed {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PathlyDashboardTheme.border, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct ExploreBadge: View {
    let title: String
    var emphasized = false

    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(emphasized ? PathlyDashboardTheme.softAccent : PathlyDashboardTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                emphasized ? PathlyDashboardTheme.accent.opacity(0.10) : PathlyDashboardTheme.elevatedSurface,
                in: Capsule()
            )
    }
}

private extension OpportunityCategory {
    var symbol: String {
        switch self {
        case .competition: "trophy.fill"
        case .hackathon: "chevron.left.forwardslash.chevron.right"
        case .research: "flask.fill"
        case .internship: "briefcase.fill"
        case .scholarship, .grant: "dollarsign.circle.fill"
        case .program, .camp: "sparkles"
        case .workshop: "hammer.fill"
        case .event: "calendar"
        case .volunteering: "heart.fill"
        case .leadership: "person.3.fill"
        case .club: "person.2.fill"
        case .fellowship: "medal.fill"
        }
    }
}

private extension OpportunityFormat {
    var symbol: String {
        switch self {
        case .online: "wifi"
        case .inPerson: "person.2"
        case .hybrid: "arrow.triangle.branch"
        }
    }
}

private extension PlaceType {
    var symbol: String {
        switch self {
        case .library: "books.vertical.fill"
        case .makerspace, .fabLab, .hackerspace, .innovationLab: "wrench.and.screwdriver.fill"
        case .museum, .scienceCenter: "building.columns.fill"
        case .university: "graduationcap.fill"
        case .roboticsClub: "gearshape.2.fill"
        case .communityCenter, .youthCenter: "person.3.fill"
        case .observatory: "moon.stars.fill"
        }
    }
}

private extension Place {
    var locationLabel: String {
        let components: [String] = [city, state]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return components.isEmpty ? country : components.joined(separator: ", ")
    }
}

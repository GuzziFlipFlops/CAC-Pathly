import Foundation

enum PathlyAssistantCommand: Equatable {
    case search
    case compare
    case surprise(SurpriseMode)
    case save(String)
    case unsave(String)
    case interested(String)
    case notInterested(String)
    case addPermanentInterest(InterestTag)
    case showSaved
    case redirect
}

struct PathlyAISearchResult {
    let command: PathlyAssistantCommand
    let opportunities: [OpportunityRecommendation]
    let places: [Place]
}

/// Interprets compact student language into persistent conversation filters, then calls the shared engine.
struct PathlyAISearchService {
    private let engine = RecommendationEngine()
    private let calendar = Calendar(identifier: .gregorian)

    func search(
        message: String,
        state: inout PathlyConversationState,
        opportunities: [Opportunity],
        places: [Place],
        profile: UserProfile,
        savedIDs: Set<String>,
        feedback: RecommendationFeedbackSnapshot,
        now: Date = Date()
    ) -> PathlyAISearchResult {
        let text = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if isClearlyUnrelated(text) {
            return PathlyAISearchResult(command: .redirect, opportunities: [], places: [])
        }
        if let interest = permanentInterestChange(in: text) {
            return PathlyAISearchResult(command: .addPermanentInterest(interest), opportunities: [], places: [])
        }
        if text.contains("show") && text.contains("saved") || text == "saved" {
            return PathlyAISearchResult(command: .showSaved, opportunities: [], places: [])
        }
        if let id = referencedID(in: text, state: state) {
            if text.contains("unsave") || text.contains("remove") && text.contains("saved") {
                return PathlyAISearchResult(command: .unsave(id), opportunities: [], places: [])
            }
            if text.contains("save") {
                return PathlyAISearchResult(command: .save(id), opportunities: [], places: [])
            }
            if text.contains("not interested") || text.contains("don't like") || text.contains("dismiss") {
                return PathlyAISearchResult(command: .notInterested(id), opportunities: [], places: [])
            }
            if text.contains("interested") || text.contains("like this") {
                return PathlyAISearchResult(command: .interested(id), opportunities: [], places: [])
            }
        }

        if text.contains("surprise me") {
            let mode = surpriseMode(in: text)
            state.surpriseMode = mode
            state.prioritizesUnfamiliarInterests = mode == .different
            let recommendations = engine.surpriseRecommendations(
                from: opportunities,
                profile: profile,
                savedIDs: savedIDs,
                feedback: feedback,
                mode: mode,
                count: 5,
                now: now
            )
            state.recordResults(recommendations.map(\.id))
            return PathlyAISearchResult(command: .surprise(mode), opportunities: recommendations, places: [])
        }

        if isComparison(text), !state.currentResultIDs.isEmpty {
            var recommendations = state.currentResultIDs.compactMap { id in
                opportunities.first(where: { $0.id == id }).flatMap {
                    engine.recommendation(
                        for: $0,
                        profile: profile,
                        savedIDs: savedIDs,
                        feedback: feedback,
                        now: now
                    )
                }
            }
            if text.contains("selective") {
                recommendations.sort { $0.opportunity.selectivityLevel.rank > $1.opportunity.selectivityLevel.rank }
            } else {
                recommendations.sort { $0.score > $1.score }
            }
            state.recordResults(recommendations.map(\.id))
            return PathlyAISearchResult(command: .compare, opportunities: recommendations, places: [])
        }

        updateConversationState(from: text, state: &state, now: now)

        if state.catalogKind == .places {
            let results = searchPlaces(places, state: state, profile: profile)
            state.recordResults(results.map(\.id))
            return PathlyAISearchResult(command: .search, opportunities: [], places: results)
        }

        var query = state.recommendationQuery
        query.limit = 5
        let recommendations = engine.recommendations(
            from: opportunities,
            profile: profile,
            query: query,
            savedIDs: savedIDs,
            feedback: feedback,
            now: now
        )
        state.recordResults(recommendations.map(\.id))
        return PathlyAISearchResult(command: .search, opportunities: recommendations, places: [])
    }

    private func updateConversationState(from text: String, state: inout PathlyConversationState, now: Date) {
        let requestsPlaces = requestedPlaceTypes(in: text)
        if !requestsPlaces.isEmpty
            || ["near me", "nearby", "student resource", "library", "makerspace", "science center", "robotics club"]
                .contains(where: text.contains) {
            state.catalogKind = .places
            state.requestedPlaceTypes.formUnion(requestsPlaces)
        } else if containsOpportunityLanguage(text) {
            state.catalogKind = .opportunities
        }

        if text.contains("completely different") || text.contains("outside my usual interests")
            || text.contains("outside my normal interests") {
            state.requestedInterests.removeAll()
            state.prioritizesUnfamiliarInterests = true
            state.surpriseMode = .different
        }

        let negatedInterests = excludedInterests(in: text)
        state.excludedInterests.formUnion(negatedInterests)
        let interests = requestedInterests(in: text).subtracting(negatedInterests)
        if !interests.isEmpty {
            if text.contains("instead") || text.contains("for now") { state.requestedInterests = interests }
            else { state.requestedInterests.formUnion(interests) }
        }

        let categories = requestedCategories(in: text)
        if !categories.isEmpty {
            if text.contains("instead") || text.contains("only") { state.requestedCategories = categories }
            else { state.requestedCategories.formUnion(categories) }
        }

        let formats = requestedFormats(in: text)
        if !formats.isEmpty { state.requestedFormats = formats }
        let difficulties = requestedDifficulties(in: text)
        if !difficulties.isEmpty { state.requestedDifficulties = difficulties }
        let teamTypes = requestedTeamTypes(in: text)
        if !teamTypes.isEmpty { state.requestedTeamTypes = teamTypes }
        let states = requestedStates(in: text)
        if !states.isEmpty { state.requestedStates = states }

        if text.contains("still apply") || text.contains("still enter") || text.contains("accepting")
            || text.contains("only open") {
            state.requestedStatuses = [.open, .upcoming]
        }
        if text.contains("free") || text.contains("no cost") {
            state.freeOnly = true
            state.maximumCostUSD = 0
        } else if text.contains("don't want to spend much") || text.contains("low cost") || text.contains("cheap") {
            state.maximumCostUSD = 50
        }
        if text.contains("prestigious") || text.contains("high recognition") {
            state.highRecognitionOnly = true
        }
        if text.contains("no travel") || text.contains("without travel") || text.contains("doesn't require travel") {
            state.noTravel = true
            state.travelRadiusOverride = 0
        }
        if text.contains("willing to travel") {
            state.noTravel = false
            state.travelRadiusOverride = 50
        }
        if text.contains("build my programming") || text.contains("build programming") {
            state.requestedSkills.insert("Programming")
        }
        if let before = monthBoundary(in: text, prefix: "before", now: now) { state.deadlineBefore = before }
        if let before = monthBoundary(in: text, prefix: "by", now: now, endOfMonth: true) { state.deadlineBefore = before }
        if let after = monthBoundary(in: text, prefix: "after", now: now) { state.deadlineAfter = after }
    }

    private func searchPlaces(_ places: [Place], state: PathlyConversationState, profile: UserProfile) -> [Place] {
        var effectiveProfile = profile
        if let radius = state.travelRadiusOverride { effectiveProfile.travelRadius = max(radius, 5) }
        let stateCode = state.requestedStates.first ?? profile.inferredStateCode
        let interests = state.requestedInterests
        let requestedTypes = state.requestedPlaceTypes

        if profile.latitude != nil || profile.inferredStateCode != nil {
            return engine.nearbyPlaces(from: places, profile: effectiveProfile, limit: 20)
                .map(\.place)
                .filter { requestedTypes.isEmpty || requestedTypes.contains($0.placeType) }
                .filter { interests.isEmpty || !interests.isDisjoint(with: Set($0.interestTags)) }
                .prefix(5)
                .map { $0 }
        }

        return places.filter { place in
            guard place.status == .active || place.status == .unknown else { return false }
            if !requestedTypes.isEmpty && !requestedTypes.contains(place.placeType) { return false }
            if let stateCode, place.state != stateCode { return false }
            if !interests.isEmpty && interests.isDisjoint(with: Set(place.interestTags)) { return false }
            return true
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        .prefix(5)
        .map { $0 }
    }

    private func requestedCategories(in text: String) -> Set<OpportunityCategory> {
        let aliases: [(OpportunityCategory, [String])] = [
            (.competition, ["competition", "competitions"]),
            (.hackathon, ["hackathon", "hackathons"]),
            (.research, ["research"]),
            (.internship, ["internship", "internships"]),
            (.scholarship, ["scholarship", "scholarships"]),
            (.program, ["program", "programs"]),
            (.camp, ["camp", "camps"]),
            (.workshop, ["workshop", "workshops"]),
            (.event, ["event", "events"]),
            (.volunteering, ["volunteer", "volunteering"]),
            (.leadership, ["leadership"]),
            (.club, ["club", "clubs"]),
            (.fellowship, ["fellowship", "fellowships"]),
            (.grant, ["grant", "grants"])
        ]
        var result: Set<OpportunityCategory> = []
        for (category, terms) in aliases where terms.contains(where: { containsWholeTerm($0, in: text) }) {
            result.insert(category)
        }
        return result
    }

    private func containsWholeTerm(_ term: String, in text: String) -> Bool {
        let normalizedText = " " + text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + " "
        let normalizedTerm = term
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return normalizedText.contains(" " + normalizedTerm + " ")
    }

    private func requestedInterests(in text: String) -> Set<InterestTag> {
        var result = Set(InterestTag.allCases.filter { text.contains($0.rawValue.lowercased()) })
        if text.contains("coding") || text.contains("software") { result.insert(.programming) }
        if text.contains(" ai ") || text.hasPrefix("ai ") { result.insert(.artificialIntelligence) }
        if text.contains("math") { result.insert(.mathematics) }
        if text.contains("robot") { result.insert(.robotics) }
        if text.contains("technical") { result.formUnion([.programming, .engineering, .computerScience]) }
        return result
    }

    private func excludedInterests(in text: String) -> Set<InterestTag> {
        Set(InterestTag.allCases.filter { interest in
            let term = interest.rawValue.lowercased()
            return text.contains("not " + term)
                || text.contains("isn't " + term)
                || text.contains("isnt " + term)
                || text.contains("instead of " + term)
                || text.contains("already do " + term)
        })
    }

    private func requestedFormats(in text: String) -> Set<OpportunityFormat> {
        var result: Set<OpportunityFormat> = []
        if text.contains("online") || text.contains("virtual") { result.insert(.online) }
        if text.contains("in person") || text.contains("in-person") { result.insert(.inPerson) }
        if text.contains("hybrid") { result.insert(.hybrid) }
        return result
    }

    private func requestedDifficulties(in text: String) -> Set<DifficultyLevel> {
        var result = Set(DifficultyLevel.allCases.filter { text.contains($0.rawValue.lowercased()) })
        if text.contains("harder") || text.contains("much harder") || text.contains("challenging") {
            result.formUnion([.advanced, .expert])
        }
        return result
    }

    private func requestedTeamTypes(in text: String) -> Set<TeamType> {
        if text.contains("individual") || text.contains("on my own") || text.contains("by myself") { return [.individual] }
        if text.contains("team") { return [.team] }
        return []
    }

    private func requestedStates(in text: String) -> Set<String> {
        var result: Set<String> = []
        for (name, code) in USStateLookup.namesToCodes where text.contains(name) { result.insert(code) }
        let words = text.uppercased().components(separatedBy: CharacterSet.letters.inverted)
        for word in words where USStateLookup.validCodes.contains(word) { result.insert(word) }
        return result
    }

    private func requestedPlaceTypes(in text: String) -> Set<PlaceType> {
        Set(PlaceType.allCases.filter { text.contains($0.rawValue.lowercased()) })
    }

    private func permanentInterestChange(in text: String) -> InterestTag? {
        guard text.contains("from now on") || text.contains("permanent") || text.contains("my interests") else { return nil }
        return requestedInterests(in: text).first
    }

    private func referencedID(in text: String, state: PathlyConversationState) -> String? {
        guard !state.currentResultIDs.isEmpty else { return nil }
        if text.contains("first") { return state.currentResultIDs.first }
        if text.contains("second"), state.currentResultIDs.count > 1 { return state.currentResultIDs[1] }
        if text.contains("third"), state.currentResultIDs.count > 2 { return state.currentResultIDs[2] }
        if text.contains("that one") || text.contains("this one") || text.contains("it") {
            return state.lastReferencedItemID ?? state.currentResultIDs.first
        }
        return nil
    }

    private func surpriseMode(in text: String) -> SurpriseMode {
        if text.contains("different") || text.contains("outside") { return .different }
        if text.contains("ambitious") || text.contains("hard") || text.contains("prestigious") { return .ambitious }
        if text.contains("near") { return .nearby }
        return .personalized
    }

    private func isComparison(_ text: String) -> Bool {
        text.contains("which") || text.contains("compare") || text.contains("best fit") || text.contains("most selective")
    }

    private func containsOpportunityLanguage(_ text: String) -> Bool {
        requestedCategories(in: text).isEmpty == false
            || requestedInterests(in: text).isEmpty == false
            || ["opportunity", "apply", "deadline", "eligible", "qualify", "something harder"]
                .contains(where: text.contains)
    }

    private func isClearlyUnrelated(_ text: String) -> Bool {
        ["super bowl", "world series", "nba score", "weather forecast", "write me a recipe",
         "stock price", "celebrity gossip", "president of", "translate this paragraph"]
            .contains(where: text.contains)
    }

    private func monthBoundary(in text: String, prefix: String, now: Date, endOfMonth: Bool = false) -> Date? {
        let monthSymbols = DateFormatter().monthSymbols ?? []
        guard let monthIndex = monthSymbols.firstIndex(where: { text.contains(prefix + " " + $0.lowercased()) }) else {
            return nil
        }
        let month = monthIndex + 1
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let year = month < currentMonth ? currentYear + 1 : currentYear
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        if !endOfMonth { return start }
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)
    }
}

private extension SelectivityLevel {
    var rank: Int {
        switch self {
        case .unknown: 0
        case .open: 1
        case .competitive: 2
        case .selective: 3
        case .highlySelective: 4
        }
    }
}

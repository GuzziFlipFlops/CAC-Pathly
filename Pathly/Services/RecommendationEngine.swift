import CoreLocation
import Foundation

struct RecommendationQuery: Equatable, Sendable {
    var text: String?
    var categories: Set<OpportunityCategory> = []
    var interests: Set<InterestTag> = []
    var excludedInterests: Set<InterestTag> = []
    var skills: Set<String> = []
    var formats: Set<OpportunityFormat> = []
    var states: Set<String> = []
    var statuses: Set<OpportunityStatus> = []
    var difficulty: Set<DifficultyLevel> = []
    var teamTypes: Set<TeamType> = []
    var grade: Int?
    var age: Int?
    var freeOnly = false
    var noTravel = false
    var highRecognitionOnly = false
    var deadlineBefore: Date?
    var deadlineAfter: Date?
    var maximumCostUSD: Double?
    var travelRadiusOverride: Int?
    var excludedIDs: Set<String> = []
    var prioritizesUnfamiliarInterests = false
    var limit = 20
}

enum EligibilityConfidence: Equatable {
    case confirmed
    case potential([String])
}

enum SurpriseMode: String, Codable, Equatable {
    case personalized
    case different
    case ambitious
    case nearby
}

struct OpportunityRecommendation: Identifiable, Equatable {
    let opportunity: Opportunity
    let score: Double
    let labels: [String]
    let reasons: [String]
    let eligibility: EligibilityConfidence

    var id: String { opportunity.id }
}

struct PlaceRecommendation: Identifiable, Equatable {
    let place: Place
    let distanceMiles: Double?
    let labels: [String]

    var id: String { place.id }
}

/// Applies hard eligibility first, then computes bounded, explainable ranking signals.
struct RecommendationEngine {
    private let calendar = Calendar(identifier: .gregorian)

    func recommendations(
        from opportunities: [Opportunity],
        profile: UserProfile,
        query: RecommendationQuery = RecommendationQuery(),
        savedIDs: Set<String> = [],
        feedback: RecommendationFeedbackSnapshot = RecommendationFeedbackSnapshot(),
        now: Date = Date()
    ) -> [OpportunityRecommendation] {
        opportunities.compactMap { opportunity in
            recommendation(
                for: opportunity,
                profile: profile,
                query: query,
                savedIDs: savedIDs,
                feedback: feedback,
                now: now
            )
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.opportunity.deadline != $1.opportunity.deadline {
                return ($0.opportunity.deadline ?? .distantFuture) < ($1.opportunity.deadline ?? .distantFuture)
            }
            return $0.opportunity.name.localizedCaseInsensitiveCompare($1.opportunity.name) == .orderedAscending
        }
        .prefix(max(0, query.limit))
        .map { $0 }
    }

    func recommendation(
        for opportunity: Opportunity,
        profile: UserProfile,
        query: RecommendationQuery = RecommendationQuery(),
        savedIDs: Set<String> = [],
        feedback: RecommendationFeedbackSnapshot = RecommendationFeedbackSnapshot(),
        now: Date = Date()
    ) -> OpportunityRecommendation? {
        guard isEligible(opportunity, profile: profile, query: query, now: now) else { return nil }

        let profileInterests = mappedInterests(profile.interests)
        let activeInterests = query.interests.isEmpty ? profileInterests : query.interests
        let opportunityInterests = Set(opportunity.interestTags)
        let interestMatches = activeInterests.intersection(opportunityInterests)

        let profileSkills = Set(profile.skills.map(normalize))
        let activeSkills = query.skills.isEmpty ? profileSkills : Set(query.skills.map(normalize))
        let recommendedSkills = Set(opportunity.recommendedSkills.map(normalize))
        let requiredSkills = Set(opportunity.requiredSkills.map(normalize))
        let recommendedMatches = activeSkills.intersection(recommendedSkills)
        let requiredMatches = activeSkills.intersection(requiredSkills)
        let preferredCategories = mappedCategories(profile.opportunityTypes)

        var score = 20.0
        var reasons: [String] = []

        if !interestMatches.isEmpty {
            score += min(30, Double(interestMatches.count) * 12)
            reasons.append("Matches " + interestMatches.map(\.rawValue).sorted().joined(separator: ", "))
        }
        if query.prioritizesUnfamiliarInterests,
           profileInterests.isDisjoint(with: opportunityInterests) {
            score += 15
            reasons.append("Explores beyond your usual interests")
        }
        if !recommendedMatches.isEmpty || !requiredMatches.isEmpty {
            score += min(18, Double(recommendedMatches.count) * 5 + Double(requiredMatches.count) * 7)
            reasons.append("Uses skills you selected")
        }
        if profile.isOpenToAnything || preferredCategories.contains(opportunity.category) {
            score += profile.isOpenToAnything ? 2 : 9
            if !profile.isOpenToAnything { reasons.append("A preferred opportunity type") }
        }
        if let state = effectiveState(profile: profile, query: query), opportunity.eligibleStates.contains(state) {
            score += 8
            reasons.append("Available in \(state)")
        }
        if opportunity.format == .online || opportunity.onlineAvailable { score += 3 }
        if opportunity.costUSD == 0 { score += 4 }
        if opportunity.status == .open { score += 5 }
        if opportunity.recognitionLevel == .high || opportunity.recognitionLevel == .exceptional { score += 5 }
        if savedIDs.contains(opportunity.id) { score += 3 }

        switch feedback.feedbackByID[opportunity.id] {
        case .interested: score += 8
        case .notInterested: score -= 18
        case nil: break
        }
        score -= min(6, Double(feedback.seenCounts[opportunity.id, default: 0]))

        switch profile.challengePreference {
        case "Comfortable":
            if opportunity.difficultyLevel == .beginner || opportunity.difficultyLevel == .intermediate { score += 4 }
            if opportunity.difficultyLevel == .expert { score -= 6 }
        case "Challenge Me":
            if opportunity.difficultyLevel == .advanced || opportunity.difficultyLevel == .expert { score += 5 }
        default:
            if opportunity.difficultyLevel == .intermediate || opportunity.difficultyLevel == .advanced { score += 3 }
        }

        switch profile.teamPreference {
        case "Individual":
            if opportunity.teamType == .individual { score += 5 }
            if opportunity.teamType == .team { score -= 6 }
        case "Team":
            if opportunity.teamType == .team { score += 5 }
            if opportunity.teamType == .individual { score -= 4 }
        default:
            if opportunity.teamType == .individualOrTeam { score += 2 }
        }

        let eligibility = eligibilityConfidence(for: opportunity)

        var labels = [eligibilityLabel(score: score, confidence: eligibility)]
        if opportunity.costUSD == 0 { labels.append("Free") }
        if opportunity.format == .online { labels.append("Online") }
        if opportunity.recognitionLevel == .high || opportunity.recognitionLevel == .exceptional {
            labels.append("High recognition")
        }
        if let deadline = opportunity.deadline,
           let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: deadline).day,
           (0...45).contains(days) {
            labels.append("Deadline soon")
        }
        if let state = effectiveState(profile: profile, query: query), opportunity.eligibleStates.contains(state) {
            labels.append("In your state")
        }

        if reasons.isEmpty { reasons.append("Eligible based on the available record") }
        return OpportunityRecommendation(
            opportunity: opportunity,
            score: max(0, score),
            labels: Array(labels.prefix(3)),
            reasons: reasons,
            eligibility: eligibility
        )
    }

    func deadlineRecommendations(
        from opportunities: [Opportunity],
        profile: UserProfile,
        savedIDs: Set<String>,
        feedback: RecommendationFeedbackSnapshot,
        now: Date = Date(),
        limit: Int = 4
    ) -> [OpportunityRecommendation] {
        var query = RecommendationQuery()
        query.limit = opportunities.count
        // Deadlines follow the opportunity types the student asked for, when they chose any.
        if !profile.isOpenToAnything {
            query.categories = mappedCategories(profile.opportunityTypes)
        }
        return recommendations(
            from: opportunities,
            profile: profile,
            query: query,
            savedIDs: savedIDs,
            feedback: feedback,
            now: now
        )
        .filter { $0.opportunity.deadline != nil && $0.opportunity.status.isCurrent }
        .sorted { ($0.opportunity.deadline ?? .distantFuture) < ($1.opportunity.deadline ?? .distantFuture) }
        .prefix(limit)
        .map { $0 }
    }

    func surpriseRecommendations(
        from opportunities: [Opportunity],
        profile: UserProfile,
        savedIDs: Set<String>,
        feedback: RecommendationFeedbackSnapshot,
        mode: SurpriseMode = .personalized,
        count: Int = 4,
        now: Date = Date()
    ) -> [OpportunityRecommendation] {
        var query = RecommendationQuery()
        query.limit = 80
        var pool = recommendations(
            from: opportunities,
            profile: profile,
            query: query,
            savedIDs: savedIDs,
            feedback: feedback,
            now: now
        )

        let previous = Set(feedback.lastSurpriseIDs)
        let freshPool = pool.filter { !previous.contains($0.id) }
        if freshPool.count >= count { pool = freshPool }

        var selected: [OpportunityRecommendation] = []
        while !pool.isEmpty && selected.count < count {
            let selectedCategories = Set(selected.map { $0.opportunity.category })
            let weights = pool.map { recommendation -> Double in
                let unseenBoost = 1 / Double(1 + feedback.seenCounts[recommendation.id, default: 0])
                let diversityBoost = selectedCategories.contains(recommendation.opportunity.category) ? 0.45 : 1.25
                let modeBoost: Double
                switch mode {
                case .personalized:
                    modeBoost = 1
                case .different:
                    let profileInterests = mappedInterests(profile.interests)
                    modeBoost = profileInterests.isDisjoint(with: Set(recommendation.opportunity.interestTags)) ? 2.1 : 0.55
                case .ambitious:
                    let isAmbitious = recommendation.opportunity.difficultyLevel == .advanced
                        || recommendation.opportunity.difficultyLevel == .expert
                        || recommendation.opportunity.selectivityLevel == .selective
                        || recommendation.opportunity.selectivityLevel == .highlySelective
                        || recommendation.opportunity.recognitionLevel == .high
                        || recommendation.opportunity.recognitionLevel == .exceptional
                    modeBoost = isAmbitious ? 1.9 : 0.65
                case .nearby:
                    let state = profile.inferredStateCode
                    let isNearby = state.map(recommendation.opportunity.eligibleStates.contains) == true
                        || recommendation.opportunity.format == .online
                    modeBoost = isNearby ? 1.8 : 0.55
                }
                return max(0.1, (recommendation.score + 10) * unseenBoost * diversityBoost * modeBoost)
            }
            let total = weights.reduce(0, +)
            var draw = Double.random(in: 0..<max(total, 0.1))
            var chosenIndex = 0
            for (index, weight) in weights.enumerated() {
                draw -= weight
                if draw <= 0 {
                    chosenIndex = index
                    break
                }
            }
            selected.append(pool.remove(at: chosenIndex))
        }
        return selected
    }

    func nearbyPlaces(
        from places: [Place],
        profile: UserProfile,
        coordinateOverride: CLLocationCoordinate2D? = nil,
        limit: Int = 4
    ) -> [PlaceRecommendation] {
        let state = profile.inferredStateCode
        let origin: CLLocation? = {
            if let coordinateOverride {
                return CLLocation(latitude: coordinateOverride.latitude, longitude: coordinateOverride.longitude)
            }
            guard let latitude = profile.latitude, let longitude = profile.longitude else { return nil }
            return CLLocation(latitude: latitude, longitude: longitude)
        }()
        let interests = mappedInterests(profile.interests)

        let ranked: [(Place, Double?, Int)] = places.compactMap { place in
            guard place.status == .active || place.status == .unknown else { return nil }
            let distance: Double?
            if let origin, let latitude = place.latitude, let longitude = place.longitude {
                distance = origin.distance(from: CLLocation(latitude: latitude, longitude: longitude)) / 1_609.344
            } else {
                distance = nil
            }
            let interestScore = interests.intersection(Set(place.interestTags)).count
            return (place, distance, interestScore)
        }
        .filter { place, distance, _ in
            if let distance { return distance <= Double(max(profile.travelRadius, 5)) }
            if let state { return place.state == state }
            return false
        }
        .sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            if lhs.1 != rhs.1 { return (lhs.1 ?? .greatestFiniteMagnitude) < (rhs.1 ?? .greatestFiniteMagnitude) }
            return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
        }

        return ranked.prefix(limit).map { place, distance, interestScore in
            var labels: [String] = []
            if let distance { labels.append(distance < 0.5 ? "Nearby" : "\(distance.formatted(.number.precision(.fractionLength(1)))) mi") }
            if place.freeAccess == true { labels.append("Free access") }
            if interestScore > 0 { labels.append("Matches your interests") }
            return PlaceRecommendation(place: place, distanceMiles: distance, labels: labels)
        }
    }

    private func isEligible(
        _ opportunity: Opportunity,
        profile: UserProfile,
        query: RecommendationQuery,
        now: Date
    ) -> Bool {
        guard opportunity.status.isCurrent else { return false }
        if query.excludedIDs.contains(opportunity.id) { return false }
        if let deadline = opportunity.deadline, deadline < calendar.startOfDay(for: now) { return false }

        let grade = query.grade ?? profile.gradeLevel
        if let grade, let minimum = opportunity.minGrade, grade < minimum { return false }
        if let grade, let maximum = opportunity.maxGrade, grade > maximum { return false }

        let age = query.age ?? profile.age
        if let minimum = opportunity.minAge, age < minimum { return false }
        if let maximum = opportunity.maxAge, age > maximum { return false }

        let countries = Set(opportunity.eligibleCountries.map { $0.uppercased() })
        if !countries.isEmpty && !countries.contains("US") && !countries.contains("ALL") { return false }

        if !opportunity.eligibleStates.isEmpty && !opportunity.eligibleStates.contains("ALL") {
            guard let state = effectiveState(profile: profile, query: query),
                  opportunity.eligibleStates.contains(state) else { return false }
        }

        if !profile.showsOnline && opportunity.format == .online { return false }
        if !profile.showsInPerson && opportunity.format == .inPerson { return false }
        if !profile.showsOnline && !profile.showsInPerson { return false }

        if query.freeOnly, opportunity.costUSD != 0 { return false }
        if query.noTravel, opportunity.travelRequired && !opportunity.onlineAvailable { return false }
        if query.highRecognitionOnly,
           opportunity.recognitionLevel != .high && opportunity.recognitionLevel != .exceptional { return false }

        if let maximumCost = profile.maximumPreferredCost {
            guard let cost = opportunity.costUSD,
                  NSDecimalNumber(decimal: cost).doubleValue <= maximumCost else { return false }
        }
        if let maximumCost = query.maximumCostUSD {
            guard let cost = opportunity.costUSD,
                  NSDecimalNumber(decimal: cost).doubleValue <= maximumCost else { return false }
        }

        if !query.categories.isEmpty && !query.categories.contains(opportunity.category) { return false }
        if !query.formats.isEmpty && !query.formats.contains(opportunity.format) { return false }
        if !query.statuses.isEmpty && !query.statuses.contains(opportunity.status) { return false }
        if !query.difficulty.isEmpty && !query.difficulty.contains(opportunity.difficultyLevel) { return false }
        if !query.interests.isEmpty && query.interests.isDisjoint(with: Set(opportunity.interestTags)) { return false }
        if !query.excludedInterests.isEmpty
            && !query.excludedInterests.isDisjoint(with: Set(opportunity.interestTags)) { return false }
        if !query.teamTypes.isEmpty {
            guard let teamType = opportunity.teamType,
                  query.teamTypes.contains(where: { teamType.supports($0) }) else { return false }
        }

        if !query.skills.isEmpty {
            let requested = Set(query.skills.map(normalize))
            let catalogSkills = Set((opportunity.requiredSkills + opportunity.recommendedSkills).map(normalize))
            if requested.isDisjoint(with: catalogSkills) { return false }
        }
        if let deadlineBefore = query.deadlineBefore {
            guard let deadline = opportunity.deadline, deadline <= deadlineBefore else { return false }
        }
        if let deadlineAfter = query.deadlineAfter {
            guard let deadline = opportunity.deadline, deadline >= deadlineAfter else { return false }
        }
        if let text = query.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let searchable = [
                opportunity.name, opportunity.subcategory, opportunity.descriptionShort,
                opportunity.descriptionFull, opportunity.category.rawValue,
                opportunity.interestTags.map(\.rawValue).joined(separator: " "),
                opportunity.requiredSkills.joined(separator: " "),
                opportunity.recommendedSkills.joined(separator: " ")
            ].compactMap { $0 }.joined(separator: " ")
            if !searchable.localizedCaseInsensitiveContains(text) { return false }
        }
        return true
    }

    private func effectiveState(profile: UserProfile, query: RecommendationQuery) -> String? {
        query.states.first ?? profile.inferredStateCode
    }

    private func eligibilityLabel(score: Double, confidence: EligibilityConfidence) -> String {
        if case .potential = confidence { return "Potential match" }
        if score >= 58 { return "Excellent match" }
        if score >= 42 { return "Strong match" }
        return "Eligible"
    }

    private func eligibilityConfidence(for opportunity: Opportunity) -> EligibilityConfidence {
        var unknowns: [String] = []
        if opportunity.status == .unknown { unknowns.append("Application status is unknown") }
        if opportunity.minGrade == nil && opportunity.maxGrade == nil
            && opportunity.minAge == nil && opportunity.maxAge == nil {
            unknowns.append("Grade and age criteria are not stored")
        }
        if opportunity.eligibleCountries.isEmpty { unknowns.append("Country eligibility is not stored") }
        if opportunity.eligibleStates.isEmpty { unknowns.append("State eligibility is not stored") }
        return unknowns.isEmpty ? .confirmed : .potential(unknowns)
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mappedInterests(_ values: Set<String>) -> Set<InterestTag> {
        var result: Set<InterestTag> = []
        for value in values {
            if let exact = InterestTag(rawValue: value) { result.insert(exact) }
            switch value {
            case "Math": result.insert(.mathematics)
            case "Art & Design": result.formUnion([.art, .design])
            default: break
            }
        }
        return result
    }

    private func mappedCategories(_ values: Set<String>) -> Set<OpportunityCategory> {
        var result: Set<OpportunityCategory> = []
        for value in values {
            switch value {
            case "Competitions": result.insert(.competition)
            case "Hackathons": result.insert(.hackathon)
            case "Research": result.insert(.research)
            case "Internships": result.insert(.internship)
            case "Scholarships": result.insert(.scholarship)
            case "Programs & Camps": result.formUnion([.program, .camp])
            case "Volunteering": result.insert(.volunteering)
            case "Workshops & Events": result.formUnion([.workshop, .event])
            case "Clubs": result.insert(.club)
            default: break
            }
        }
        return result
    }
}

private extension OpportunityStatus {
    var isCurrent: Bool { self == .open || self == .upcoming || self == .unknown }
}

private extension UserProfile {
    var maximumPreferredCost: Double? {
        switch costPreference {
        case "Free only": 0
        case "Under $50": 50
        case "Under $200": 200
        default: nil
        }
    }
}

private extension TeamType {
    func supports(_ requested: TeamType) -> Bool {
        switch (self, requested) {
        case (.individualOrTeam, _), (_, .individualOrTeam): true
        default: self == requested
        }
    }
}

import Foundation

struct PathlyAIResponse: Equatable {
    let text: String
    let opportunityIDs: [String]
    let placeIDs: [String]
    let usedLanguageModel: Bool
}

/// Domain coordinator: structured intent, deterministic retrieval/actions, optional generation, canonical IDs.
@MainActor
final class PathlyAssistantService {
    private let repository: any OpportunityRepository
    private let profileStore: OnboardingStore
    private let savedItems: SavedItemsStore
    private let feedbackStore: RecommendationFeedbackStore
    private let discoveryStore: PathlyDiscoveryStore
    private let searchService = PathlyAISearchService()
    private let recommendationEngine = RecommendationEngine()
    private var provider: any PathlyLanguageModelProvider

    private(set) var conversationState = PathlyConversationState()

    var availability: PathlyAIAvailability { provider.availability }
    private var opportunities: [Opportunity] { repository.opportunities }
    private var places: [Place] { repository.places }
    private var organizations: [Organization] { repository.organizations }

    init(
        repository: any OpportunityRepository,
        profileStore: OnboardingStore,
        savedItems: SavedItemsStore,
        feedbackStore: RecommendationFeedbackStore,
        discoveryStore: PathlyDiscoveryStore
    ) {
        self.repository = repository
        self.profileStore = profileStore
        self.savedItems = savedItems
        self.feedbackStore = feedbackStore
        self.discoveryStore = discoveryStore

        let index = PathlyAIToolIndex(
            opportunities: repository.opportunities,
            places: repository.places,
            organizations: repository.organizations,
            profile: profileStore.profile,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
        provider = AppleFoundationModelProvider(index: index, profileSummary: Self.profileSummary(profileStore.profile))
    }

    /// Predefined demo reply, if one applies. Always nil in Release builds.
    func scriptedReply(to message: String) -> PathlyScriptedReply? {
        #if DEBUG
        guard PathlyDemoScript.isEnabled,
              let reply = PathlyDemoScript.reply(to: message, catalogCount: opportunities.count) else { return nil }
        for id in reply.savesOpportunityIDs where canonicalItemExists(id) {
            savedItems.save(id)
        }
        return reply
        #else
        return nil
        #endif
    }

    func respond(to message: String) async -> PathlyAIResponse {
        var state = conversationState
        let result = searchService.search(
            message: message,
            state: &state,
            opportunities: opportunities,
            places: places,
            profile: profileStore.profile,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
        conversationState = state

        if let actionResponse = perform(result.command) {
            return actionResponse
        }

        if result.command == .redirect {
            return PathlyAIResponse(
                text: "I specialize in student opportunities and educational resources rather than general trivia. I can help you find a competition, scholarship, program, internship, club, or something useful near you.",
                opportunityIDs: [],
                placeIDs: [],
                usedLanguageModel: false
            )
        }

        discoveryStore.apply(state)
        if case .surprise = result.command {
            feedbackStore.markShown(result.opportunities.map(\.id), asSurprise: true)
        }

        let prefetchedOpportunityIDs = result.opportunities.map(\.id)
        let prefetchedPlaceIDs = result.places.map(\.id)
        if prefetchedOpportunityIDs.isEmpty && prefetchedPlaceIDs.isEmpty {
            return PathlyAIResponse(
                text: deterministicExplanation(for: result),
                opportunityIDs: [],
                placeIDs: [],
                usedLanguageModel: false
            )
        }
        rebuildProvider()

        let request = LanguageModelProviderRequest(
            message: message,
            conversationState: state.summaryText,
            prefetchedCatalogContext: prefetchedContext(for: result)
        )

        // During demo recording, unscripted questions use catalog search only so nothing stalls on camera.
        var usesModel = provider.availability.isAvailable
        #if DEBUG
        if PathlyDemoScript.isEnabled { usesModel = false }
        #endif

        if usesModel,
           let generated = try? await provider.respond(to: request) {
            let toolOpportunityIDs = validatedOpportunityIDs(generated.opportunityIDs)
            let toolPlaceIDs = validatedPlaceIDs(generated.placeIDs)
            return PathlyAIResponse(
                text: generated.text,
                opportunityIDs: toolOpportunityIDs.isEmpty ? prefetchedOpportunityIDs : toolOpportunityIDs,
                placeIDs: toolPlaceIDs.isEmpty ? prefetchedPlaceIDs : toolPlaceIDs,
                usedLanguageModel: true
            )
        }

        return PathlyAIResponse(
            text: deterministicExplanation(for: result),
            opportunityIDs: prefetchedOpportunityIDs,
            placeIDs: prefetchedPlaceIDs,
            usedLanguageModel: false
        )
    }

    private func perform(_ command: PathlyAssistantCommand) -> PathlyAIResponse? {
        switch command {
        case .save(let id):
            guard canonicalItemExists(id) else { return unknownItemResponse() }
            savedItems.save(id)
            return actionResponse("Saved. It’s now available in your Saved tab.")
        case .unsave(let id):
            savedItems.remove(id)
            return actionResponse("Removed it from Saved.")
        case .interested(let id):
            feedbackStore.applyFeedback(.interested, for: id)
            return actionResponse("Marked as Interested. Pathly will give similar eligible options a small ranking boost.")
        case .notInterested(let id):
            feedbackStore.applyFeedback(.notInterested, for: id)
            conversationState.rejectedItemIDs.insert(id)
            discoveryStore.apply(conversationState)
            return actionResponse("Marked as Not interested. I’ll avoid that item in this conversation and reduce similar recommendations slightly.")
        case .addPermanentInterest(let interest):
            profileStore.profile.interests.insert(interest.rawValue)
            return actionResponse("Added \(interest.rawValue) to your permanent Pathly interests. Home and future recommendations will update too.")
        case .showSaved:
            let opportunityIDs = savedItems.itemIDs.filter { id in opportunities.contains { $0.id == id } }
            let placeIDs = savedItems.itemIDs.filter { id in places.contains { $0.id == id } }
            let count = opportunityIDs.count + placeIDs.count
            return PathlyAIResponse(
                text: count == 0 ? "You haven’t saved anything yet." : "Here are your saved Pathly items.",
                opportunityIDs: Array(opportunityIDs.prefix(8)),
                placeIDs: Array(placeIDs.prefix(8)),
                usedLanguageModel: false
            )
        case .search, .compare, .surprise:
            return nil
        case .redirect:
            return nil
        }
    }

    private func deterministicExplanation(for result: PathlyAISearchResult) -> String {
        if let first = result.opportunities.first {
            let count = result.opportunities.count
            var statement = count == 1 ? "Here's one option that fits." : "Here are \(count) options that fit."
            statement += " **\(first.opportunity.name)** is the top pick"
            if let reason = first.reasons.first {
                statement += ": " + reason.lowercased()
            }
            statement += "."
            if case .potential = first.eligibility {
                statement += " Check its official page to confirm you're eligible."
            }
            return statement
        }
        if !result.places.isEmpty {
            return "I found \(result.places.count) Pathly \(result.places.count == 1 ? "resource" : "resources") matching your current location and filters."
        }
        return "I couldn’t find a canonical Pathly record matching those filters. Try relaxing the team, deadline, location, cost, or difficulty requirement—I won’t invent an option that isn’t in the catalog."
    }

    private func prefetchedContext(for result: PathlyAISearchResult) -> String {
        let opportunityLines = result.opportunities.map { recommendation in
            let opportunity = recommendation.opportunity
            let organization = opportunity.organizationID.flatMap { id in organizations.first { $0.id == id }?.name } ?? "Unknown"
            let eligibility: String
            switch recommendation.eligibility {
            case .confirmed: eligibility = "confirmed from represented hard fields"
            case .potential(let unknowns): eligibility = "potential; unknown: " + unknowns.joined(separator: ", ")
            }
            let deadline = opportunity.deadline.map(Self.dateFormatter.string) ?? "Unknown"
            let cost: String
            if let amount = opportunity.costUSD {
                cost = amount == 0 ? "Free" : "$" + NSDecimalNumber(decimal: amount).stringValue
            } else {
                cost = "Unknown"
            }
            let fields: [String] = [
                "ID=" + opportunity.id,
                "name=" + opportunity.name,
                "organization=" + organization,
                "category=" + opportunity.category.rawValue,
                "team=" + (opportunity.teamType?.rawValue ?? "Unknown"),
                "format=" + opportunity.format.rawValue,
                "status=" + opportunity.status.rawValue,
                "deadline=" + deadline,
                "cost=" + cost,
                "difficulty=" + opportunity.difficultyLevel.rawValue,
                "selectivity=" + opportunity.selectivityLevel.rawValue,
                "recognition=" + (opportunity.recognitionLevel?.rawValue ?? "Unknown"),
                "eligibility=" + eligibility,
                "reasons=" + recommendation.reasons.joined(separator: ", ")
            ]
            return fields.joined(separator: " | ")
        }
        let placeLines = result.places.map { place in
            let location = [place.city, place.state].compactMap { $0 }.joined(separator: ", ")
            let freeAccess = place.freeAccess.map { $0 ? "Yes" : "No" } ?? "Unknown"
            let fields: [String] = [
                "ID=" + place.id,
                "name=" + place.name,
                "type=" + place.placeType.rawValue,
                "location=" + location,
                "freeAccess=" + freeAccess,
                "status=" + place.status.rawValue
            ]
            return fields.joined(separator: " | ")
        }
        let lines = opportunityLines + placeLines
        return lines.isEmpty ? "No canonical result matched." : lines.joined(separator: "\n")
    }

    private func rebuildProvider() {
        let index = PathlyAIToolIndex(
            opportunities: opportunities,
            places: places,
            organizations: organizations,
            profile: profileStore.profile,
            savedIDs: Set(savedItems.itemIDs),
            feedback: feedbackStore.snapshot
        )
        provider = AppleFoundationModelProvider(index: index, profileSummary: Self.profileSummary(profileStore.profile))
    }

    private func canonicalItemExists(_ id: String) -> Bool {
        opportunities.contains { $0.id == id } || places.contains { $0.id == id }
    }

    private func validatedOpportunityIDs(_ ids: [String]) -> [String] {
        ids.compactMap { id in
            guard let opportunity = repository.opportunity(id: id),
                  recommendationEngine.recommendation(
                    for: opportunity,
                    profile: profileStore.profile,
                    query: conversationState.recommendationQuery,
                    savedIDs: Set(savedItems.itemIDs),
                    feedback: feedbackStore.snapshot
                  ) != nil else { return nil }
            return id
        }
    }

    private func validatedPlaceIDs(_ ids: [String]) -> [String] {
        ids.compactMap { id in
            guard let place = repository.place(id: id),
                  place.status == .active || place.status == .unknown else { return nil }
            return id
        }
    }

    private func actionResponse(_ text: String) -> PathlyAIResponse {
        PathlyAIResponse(text: text, opportunityIDs: [], placeIDs: [], usedLanguageModel: false)
    }

    private func unknownItemResponse() -> PathlyAIResponse {
        actionResponse("I couldn’t resolve that reference to a canonical Pathly item. Ask me to show the options again, then name the first, second, or third one.")
    }

    private static func profileSummary(_ profile: UserProfile) -> String {
        [
            profile.grade.map { "Grade: " + $0 },
            "Age: " + String(profile.age),
            profile.zipCode.isEmpty ? nil : "ZIP: " + profile.zipCode,
            profile.resolvedLocation.isEmpty ? nil : "Location: " + profile.resolvedLocation,
            profile.interests.isEmpty ? nil : "Interests: " + profile.interests.sorted().joined(separator: ", "),
            profile.skills.isEmpty ? nil : "Skills: " + profile.skills.sorted().joined(separator: ", "),
            profile.opportunityTypes.isEmpty ? nil : "Preferred types: " + profile.opportunityTypes.sorted().joined(separator: ", "),
            "Formats: " + [profile.showsOnline ? "online" : nil, profile.showsInPerson ? "in-person" : nil]
                .compactMap { $0 }.joined(separator: ", "),
            "Travel radius: " + String(profile.travelRadius) + " miles",
            "Cost: " + profile.costPreference,
            "Team: " + profile.teamPreference,
            "Challenge: " + profile.challengePreference
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

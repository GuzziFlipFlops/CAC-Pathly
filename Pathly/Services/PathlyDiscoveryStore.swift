import Combine
import Foundation

enum PathlyCatalogKind: String, Equatable {
    case opportunities
    case places
}

struct PathlyConversationState: Equatable {
    var catalogKind: PathlyCatalogKind = .opportunities
    var requestedInterests: Set<InterestTag> = []
    var excludedInterests: Set<InterestTag> = []
    var requestedCategories: Set<OpportunityCategory> = []
    var requestedSkills: Set<String> = []
    var requestedTeamTypes: Set<TeamType> = []
    var requestedDifficulties: Set<DifficultyLevel> = []
    var requestedFormats: Set<OpportunityFormat> = []
    var requestedPlaceTypes: Set<PlaceType> = []
    var requestedStatuses: Set<OpportunityStatus> = []
    var requestedStates: Set<String> = []
    var maximumCostUSD: Double?
    var deadlineBefore: Date?
    var deadlineAfter: Date?
    var travelRadiusOverride: Int?
    var freeOnly = false
    var noTravel = false
    var highRecognitionOnly = false
    var prioritizesUnfamiliarInterests = false
    var surpriseMode: SurpriseMode = .personalized
    var shownItemIDs: [String] = []
    var rejectedItemIDs: Set<String> = []
    var currentResultIDs: [String] = []
    var lastReferencedItemID: String?
    var compactSummary = ""
    var turnCount = 0

    var recommendationQuery: RecommendationQuery {
        var query = RecommendationQuery()
        query.categories = requestedCategories
        query.interests = requestedInterests
        query.excludedInterests = excludedInterests
        query.skills = requestedSkills
        query.formats = requestedFormats
        query.states = requestedStates
        query.statuses = requestedStatuses
        query.difficulty = requestedDifficulties
        query.teamTypes = requestedTeamTypes
        query.freeOnly = freeOnly
        query.noTravel = noTravel
        query.highRecognitionOnly = highRecognitionOnly
        query.deadlineBefore = deadlineBefore
        query.deadlineAfter = deadlineAfter
        query.maximumCostUSD = maximumCostUSD
        query.travelRadiusOverride = travelRadiusOverride
        query.excludedIDs = rejectedItemIDs
        query.prioritizesUnfamiliarInterests = prioritizesUnfamiliarInterests
        return query
    }

    mutating func recordResults(_ ids: [String]) {
        currentResultIDs = ids
        shownItemIDs.append(contentsOf: ids.filter { !shownItemIDs.contains($0) })
        lastReferencedItemID = ids.first
        turnCount += 1
        compactSummary = summaryText
    }

    var summaryText: String {
        var parts: [String] = []
        if !requestedCategories.isEmpty {
            parts.append("categories=" + requestedCategories.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !requestedInterests.isEmpty {
            parts.append("interests=" + requestedInterests.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !excludedInterests.isEmpty {
            parts.append("excludedInterests=" + excludedInterests.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !requestedTeamTypes.isEmpty {
            parts.append("team=" + requestedTeamTypes.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !requestedDifficulties.isEmpty {
            parts.append("difficulty=" + requestedDifficulties.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !requestedFormats.isEmpty {
            parts.append("format=" + requestedFormats.map(\.rawValue).sorted().joined(separator: ","))
        }
        if !requestedPlaceTypes.isEmpty {
            parts.append("placeTypes=" + requestedPlaceTypes.map(\.rawValue).sorted().joined(separator: ","))
        }
        if freeOnly { parts.append("freeOnly=true") }
        if noTravel { parts.append("noTravel=true") }
        if highRecognitionOnly { parts.append("highRecognition=true") }
        if prioritizesUnfamiliarInterests { parts.append("exploration=true") }
        if !currentResultIDs.isEmpty { parts.append("currentResults=" + currentResultIDs.joined(separator: ",")) }
        return parts.isEmpty ? "No temporary filters" : parts.joined(separator: "; ")
    }
}

/// Shared, temporary discovery intent. It can influence Home without changing permanent onboarding choices.
@MainActor
final class PathlyDiscoveryStore: ObservableObject {
    @Published private(set) var recommendationQuery = RecommendationQuery()
    @Published private(set) var surpriseMode: SurpriseMode = .personalized
    @Published private(set) var revision = UUID()

    func apply(_ state: PathlyConversationState) {
        recommendationQuery = state.recommendationQuery
        surpriseMode = state.surpriseMode
        revision = UUID()
    }

    func resetTemporaryIntent() {
        recommendationQuery = RecommendationQuery()
        surpriseMode = .personalized
        revision = UUID()
    }
}

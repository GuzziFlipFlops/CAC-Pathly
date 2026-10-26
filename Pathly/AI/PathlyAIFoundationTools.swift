import Foundation
import FoundationModels

nonisolated struct AIOpportunityRecord: Sendable {
    let id: String
    let name: String
    let organization: String
    let category: String
    let subcategory: String
    let summary: String
    let interests: [String]
    let skills: [String]
    let minGrade: Int?
    let maxGrade: Int?
    let minAge: Int?
    let maxAge: Int?
    let teamType: String
    let format: String
    let states: [String]
    let costValue: Double?
    let cost: String
    let applicationOpen: String
    let deadline: String
    let difficulty: String
    let selectivity: String
    let recognition: String
    let status: String
    let officialURL: String

    var searchText: String {
        ([name, organization, category, subcategory, summary, format, difficulty, teamType] + interests + skills)
            .joined(separator: " ")
            .lowercased()
    }

    var compactDescription: String {
        [
            "ID: " + id,
            "Name: " + name,
            "Organization: " + organization,
            "Category: " + category + (subcategory.isEmpty ? "" : " / " + subcategory),
            "Format: " + format,
            "Team: " + teamType,
            "Status: " + status,
            "Application opens: " + applicationOpen,
            "Deadline: " + deadline,
            "Cost: " + cost,
            "Difficulty: " + difficulty,
            "Selectivity: " + selectivity,
            "Recognition: " + recognition,
            "Summary: " + summary
        ].joined(separator: " | ")
    }
}

nonisolated struct AIPlaceRecord: Sendable {
    let id: String
    let name: String
    let organization: String
    let type: String
    let summary: String
    let city: String
    let state: String
    let resources: [String]
    let interests: [String]
    let freeAccess: String
    let status: String
    let website: String

    var searchText: String {
        ([name, organization, type, summary, city, state] + resources + interests)
            .joined(separator: " ")
            .lowercased()
    }

    var compactDescription: String {
        [
            "ID: " + id,
            "Name: " + name,
            "Organization: " + organization,
            "Type: " + type,
            "Location: " + [city, state].filter { !$0.isEmpty }.joined(separator: ", "),
            "Free access: " + freeAccess,
            "Status: " + status,
            "Summary: " + summary
        ].joined(separator: " | ")
    }
}

/// Compact immutable projection used by three model tools. The complete JSON is never prompted.
nonisolated struct PathlyAIToolIndex: Sendable {
    let opportunities: [AIOpportunityRecord]
    let places: [AIPlaceRecord]
    let eligibleOpportunityIDs: [String]
    let savedIDs: [String]
    let profileState: String?

    @MainActor
    init(
        opportunities: [Opportunity],
        places: [Place],
        organizations: [Organization],
        profile: UserProfile,
        savedIDs: Set<String>,
        feedback: RecommendationFeedbackSnapshot
    ) {
        let organizationsByID = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0.name) })
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        self.opportunities = opportunities.map { opportunity in
            AIOpportunityRecord(
                id: opportunity.id,
                name: opportunity.name,
                organization: opportunity.organizationID.flatMap { organizationsByID[$0] } ?? "Unknown",
                category: opportunity.category.rawValue,
                subcategory: opportunity.subcategory ?? "",
                summary: opportunity.descriptionShort,
                interests: opportunity.interestTags.map(\.rawValue),
                skills: opportunity.requiredSkills + opportunity.recommendedSkills,
                minGrade: opportunity.minGrade,
                maxGrade: opportunity.maxGrade,
                minAge: opportunity.minAge,
                maxAge: opportunity.maxAge,
                teamType: opportunity.teamType?.rawValue ?? "Unknown",
                format: opportunity.format.rawValue,
                states: opportunity.eligibleStates,
                costValue: opportunity.costUSD.map { NSDecimalNumber(decimal: $0).doubleValue },
                cost: opportunity.costUSD.map {
                    $0 == 0 ? "Free" : NSDecimalNumber(decimal: $0).doubleValue.formatted(.currency(code: "USD"))
                } ?? "Unknown",
                applicationOpen: opportunity.applicationOpen.map(formatter.string) ?? "Unknown",
                deadline: opportunity.deadline.map(formatter.string) ?? "Unknown",
                difficulty: opportunity.difficultyLevel.rawValue,
                selectivity: opportunity.selectivityLevel.rawValue,
                recognition: opportunity.recognitionLevel?.rawValue ?? "Unknown",
                status: opportunity.status.rawValue,
                officialURL: opportunity.officialURL.absoluteString
            )
        }

        self.places = places.map { place in
            AIPlaceRecord(
                id: place.id,
                name: place.name,
                organization: place.organizationID.flatMap { organizationsByID[$0] } ?? "Unknown",
                type: place.placeType.rawValue,
                summary: place.description ?? "Unknown",
                city: place.city ?? "",
                state: place.state ?? "",
                resources: place.resourceTags,
                interests: place.interestTags.map(\.rawValue),
                freeAccess: place.freeAccess.map { $0 ? "Yes" : "No" } ?? "Unknown",
                status: place.status.rawValue,
                website: place.website?.absoluteString ?? "Unknown"
            )
        }

        var query = RecommendationQuery()
        query.limit = opportunities.count
        eligibleOpportunityIDs = RecommendationEngine().recommendations(
            from: opportunities,
            profile: profile,
            query: query,
            savedIDs: savedIDs,
            feedback: feedback
        ).map(\.id)
        self.savedIDs = savedIDs.sorted()
        profileState = profile.inferredStateCode
    }

    func search(arguments: SearchPathlyCatalogArguments) -> (opportunities: [AIOpportunityRecord], places: [AIPlaceRecord]) {
        let kind = arguments.kind?.lowercased() ?? "opportunities"
        let query = arguments.query?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let interest = arguments.interest?.lowercased()
        let excludedInterest = arguments.excludedInterest?.lowercased()
        let state = arguments.state?.uppercased() ?? profileState
        let limit = min(max(arguments.limit ?? 5, 1), 8)

        if kind.contains("place") || kind.contains("resource") {
            let type = arguments.categoryOrPlaceType?.lowercased()
            let matches = places.filter { record in
                guard record.status == "Active" || record.status == "Unknown" else { return false }
                if let query, !query.isEmpty, !record.searchText.contains(query) { return false }
                if let type, !type.isEmpty, record.type.lowercased() != type { return false }
                if let interest, !interest.isEmpty,
                   !record.interests.contains(where: { $0.lowercased().contains(interest) }) { return false }
                if let excludedInterest, !excludedInterest.isEmpty,
                   record.interests.contains(where: { $0.lowercased().contains(excludedInterest) }) { return false }
                if let state, !state.isEmpty, record.state != state { return false }
                if arguments.freeOnly == true && record.freeAccess != "Yes" { return false }
                return true
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return ([], Array(matches.prefix(limit)))
        }

        let eligible = Set(eligibleOpportunityIDs)
        let category = arguments.categoryOrPlaceType?.lowercased()
        let skill = arguments.skill?.lowercased()
        let teamType = arguments.teamType?.lowercased()
        let format = arguments.format?.lowercased()
        let difficulty = arguments.difficulty?.lowercased()
        let status = arguments.status?.lowercased()
        let deadlineBefore = arguments.deadlineBefore.flatMap(Self.machineDate)
        let deadlineAfter = arguments.deadlineAfter.flatMap(Self.machineDate)
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let matches = opportunities.filter { record in
            guard eligible.contains(record.id) else { return false }
            if let query, !query.isEmpty, !record.searchText.contains(query) { return false }
            if let category, !category.isEmpty, record.category.lowercased() != category { return false }
            if let interest, !interest.isEmpty,
               !record.interests.contains(where: { $0.lowercased().contains(interest) }) { return false }
            if let excludedInterest, !excludedInterest.isEmpty,
               record.interests.contains(where: { $0.lowercased().contains(excludedInterest) }) { return false }
            if let skill, !skill.isEmpty,
               !record.skills.contains(where: { $0.lowercased().contains(skill) }) { return false }
            if let teamType, !teamType.isEmpty,
               record.teamType.lowercased() != teamType
                && record.teamType.lowercased() != TeamType.individualOrTeam.rawValue.lowercased() { return false }
            if let state, !record.states.isEmpty,
               !record.states.contains("ALL") && !record.states.contains(state) { return false }
            if let format, !format.isEmpty, record.format.lowercased() != format { return false }
            if let difficulty, !difficulty.isEmpty, record.difficulty.lowercased() != difficulty { return false }
            if let status, !status.isEmpty, record.status.lowercased() != status { return false }
            if arguments.freeOnly == true && record.costValue != 0 { return false }
            if let maximum = arguments.maximumCostUSD, let cost = record.costValue, cost > maximum { return false }
            if arguments.highRecognitionOnly == true
                && record.recognition != "High" && record.recognition != "Exceptional" { return false }
            if let deadlineBefore {
                guard record.deadline != "Unknown", let deadline = dateFormatter.date(from: record.deadline), deadline <= deadlineBefore else { return false }
            }
            if let deadlineAfter {
                guard record.deadline != "Unknown", let deadline = dateFormatter.date(from: record.deadline), deadline >= deadlineAfter else { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            let leftRank = eligibleOpportunityIDs.firstIndex(of: lhs.id) ?? .max
            let rightRank = eligibleOpportunityIDs.firstIndex(of: rhs.id) ?? .max
            return leftRank < rightRank
        }
        return (Array(matches.prefix(limit)), [])
    }

    private static func machineDate(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

actor PathlyAIToolResultCollector {
    private var opportunityIDs: [String] = []
    private var placeIDs: [String] = []

    func record(opportunityIDs newOpportunityIDs: [String] = [], placeIDs newPlaceIDs: [String] = []) {
        for id in newOpportunityIDs where !opportunityIDs.contains(id) { opportunityIDs.append(id) }
        for id in newPlaceIDs where !placeIDs.contains(id) { placeIDs.append(id) }
    }

    func snapshot() -> (opportunityIDs: [String], placeIDs: [String]) {
        (opportunityIDs, placeIDs)
    }
}

@Generable
nonisolated struct SearchPathlyCatalogArguments {
    @Guide(description: "opportunities or places")
    var kind: String?
    @Guide(description: "Optional words that must occur in a stored record")
    var query: String?
    @Guide(description: "One canonical opportunity category or place type")
    var categoryOrPlaceType: String?
    @Guide(description: "One requested interest")
    var interest: String?
    @Guide(description: "One interest to exclude")
    var excludedInterest: String?
    @Guide(description: "One requested skill")
    var skill: String?
    @Guide(description: "Individual, Team, or Individual or Team")
    var teamType: String?
    @Guide(description: "Online, In-Person, or Hybrid")
    var format: String?
    @Guide(description: "Beginner, Intermediate, Advanced, Expert, or Unknown")
    var difficulty: String?
    @Guide(description: "Open or Upcoming")
    var status: String?
    @Guide(description: "Two-letter U.S. state code")
    var state: String?
    @Guide(description: "YYYY-MM-DD inclusive upper deadline bound")
    var deadlineBefore: String?
    @Guide(description: "YYYY-MM-DD inclusive lower deadline bound")
    var deadlineAfter: String?
    var maximumCostUSD: Double?
    var freeOnly: Bool?
    var highRecognitionOnly: Bool?
    @Guide(description: "Number of results, from 1 through 8", .range(1...8))
    var limit: Int?
}

@Generable
nonisolated struct PathlyItemArguments {
    @Guide(description: "Stable Pathly ID beginning with opp_ or place_")
    var id: String
}

@Generable
nonisolated struct SavedItemsArguments {
    @Guide(description: "Maximum saved items to return, from 1 through 8", .range(1...8))
    var limit: Int
}

nonisolated struct SearchPathlyCatalogTool: Tool {
    let name = "searchPathlyCatalog"
    let description = "Search real, profile-eligible Pathly opportunities or real Pathly places using structured filters."
    let index: PathlyAIToolIndex
    let collector: PathlyAIToolResultCollector

    func call(arguments: SearchPathlyCatalogArguments) async throws -> String {
        let result = index.search(arguments: arguments)
        await collector.record(
            opportunityIDs: result.opportunities.map(\.id),
            placeIDs: result.places.map(\.id)
        )
        let descriptions = result.opportunities.map(\.compactDescription) + result.places.map(\.compactDescription)
        return descriptions.isEmpty
            ? "No Pathly records matched these filters."
            : descriptions.joined(separator: "\n")
    }
}

nonisolated struct GetPathlyItemTool: Tool {
    let name = "getPathlyItem"
    let description = "Return authoritative stored details for one canonical Pathly opportunity or place ID."
    let index: PathlyAIToolIndex
    let collector: PathlyAIToolResultCollector

    func call(arguments: PathlyItemArguments) async throws -> String {
        if let record = index.opportunities.first(where: { $0.id == arguments.id }) {
            await collector.record(opportunityIDs: [record.id])
            return record.compactDescription + " | Official URL: " + record.officialURL
        }
        if let record = index.places.first(where: { $0.id == arguments.id }) {
            await collector.record(placeIDs: [record.id])
            return record.compactDescription + " | Website: " + record.website
        }
        return "No canonical Pathly item exists with ID " + arguments.id + "."
    }
}

nonisolated struct GetSavedItemsTool: Tool {
    let name = "getSavedItems"
    let description = "Return the student's saved canonical Pathly items."
    let index: PathlyAIToolIndex
    let collector: PathlyAIToolResultCollector

    func call(arguments: SavedItemsArguments) async throws -> String {
        let ids = Array(index.savedIDs.prefix(min(max(arguments.limit, 1), 8)))
        let opportunityByID = Dictionary(uniqueKeysWithValues: index.opportunities.map { ($0.id, $0) })
        let placeByID = Dictionary(uniqueKeysWithValues: index.places.map { ($0.id, $0) })
        let opportunities = ids.compactMap { opportunityByID[$0] }
        let places = ids.compactMap { placeByID[$0] }
        await collector.record(opportunityIDs: opportunities.map(\.id), placeIDs: places.map(\.id))
        let descriptions = opportunities.map(\.compactDescription) + places.map(\.compactDescription)
        return descriptions.isEmpty ? "The student has no saved Pathly items." : descriptions.joined(separator: "\n")
    }
}

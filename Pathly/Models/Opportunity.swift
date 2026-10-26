import Foundation

/// A user-independent opportunity record. Match quality is intentionally not stored here.
struct Opportunity: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let organizationID: String?
    let imageAssetName: String?

    let category: OpportunityCategory
    let subcategory: String?

    let descriptionShort: String
    let descriptionFull: String?

    let interestTags: [InterestTag]
    let requiredSkills: [String]
    let recommendedSkills: [String]

    let minGrade: Int?
    let maxGrade: Int?
    let minAge: Int?
    let maxAge: Int?

    let eligibilityNotes: String?

    let teamType: TeamType?
    let minTeamSize: Int?
    let maxTeamSize: Int?

    let format: OpportunityFormat
    let geographicScope: GeographicScope
    let eligibleStates: [String]
    let eligibleCountries: [String]

    let onlineAvailable: Bool
    let travelRequired: Bool

    let costUSD: Decimal?
    let financialAid: Bool?
    /// Human-readable award details because many programs offer ranges or non-cash awards.
    let prizeValue: String?

    let applicationOpen: Date?
    let deadline: Date?
    let eventStart: Date?
    let eventEnd: Date?

    let recurring: Recurrence

    let recognitionLevel: RecognitionLevel?
    let selectivityLevel: SelectivityLevel
    let difficultyLevel: DifficultyLevel

    let officialURL: URL
    let applicationURL: URL?
    let sourceURL: URL

    let lastVerified: Date
    let status: OpportunityStatus

    enum CodingKeys: String, CodingKey {
        case id, name, category, subcategory, format, deadline, recurring, status
        case organizationID = "organization_id"
        case imageAssetName = "image_asset_name"
        case descriptionShort = "description_short"
        case descriptionFull = "description_full"
        case interestTags = "interest_tags"
        case requiredSkills = "required_skills"
        case recommendedSkills = "recommended_skills"
        case minGrade = "min_grade"
        case maxGrade = "max_grade"
        case minAge = "min_age"
        case maxAge = "max_age"
        case eligibilityNotes = "eligibility_notes"
        case teamType = "team_type"
        case minTeamSize = "min_team_size"
        case maxTeamSize = "max_team_size"
        case geographicScope = "geographic_scope"
        case eligibleStates = "eligible_states"
        case eligibleCountries = "eligible_countries"
        case onlineAvailable = "online_available"
        case travelRequired = "travel_required"
        case costUSD = "cost_usd"
        case financialAid = "financial_aid"
        case prizeValue = "prize_value"
        case applicationOpen = "application_open"
        case eventStart = "event_start"
        case eventEnd = "event_end"
        case recognitionLevel = "recognition_level"
        case selectivityLevel = "selectivity_level"
        case difficultyLevel = "difficulty_level"
        case officialURL = "official_url"
        case applicationURL = "application_url"
        case sourceURL = "source_url"
        case lastVerified = "last_verified"
    }
}

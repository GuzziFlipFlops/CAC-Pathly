import Combine
import Foundation

struct PathlyDataset {
    let opportunities: [Opportunity]
    let places: [Place]
    let organizations: [Organization]
    let opportunityLocations: [OpportunityLocation]
}

/// Abstracts the source so bundled JSON can later be replaced without changing views.
protocol PathlyDataSource {
    func load() throws -> PathlyDataset
}

struct BundledJSONDataSource: PathlyDataSource {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() throws -> PathlyDataset {
        PathlyDataset(
            opportunities: try decode([Opportunity].self, resource: "opportunities"),
            places: try decode([Place].self, resource: "places"),
            organizations: try decode([Organization].self, resource: "organizations"),
            opportunityLocations: try decode([OpportunityLocation].self, resource: "opportunity_locations")
        )
    }

    private func decode<Value: Decodable>(_ type: Value.Type, resource: String) throws -> Value {
        let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: "Data")
            ?? bundle.url(forResource: resource, withExtension: "json")

        guard let url else {
            throw DataStoreError.missingResource("\(resource).json")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DataStoreError.unreadableResource("\(resource).json", error)
        }

        do {
            return try PathlyDateCoding.decoder.decode(type, from: data)
        } catch {
            throw DataStoreError.invalidResource("\(resource).json", error)
        }
    }
}

@MainActor
final class DataStore: ObservableObject {
    @Published private(set) var opportunities: [Opportunity] = []
    @Published private(set) var places: [Place] = []
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var opportunityLocations: [OpportunityLocation] = []
    @Published private(set) var validationIssues: [DataValidationIssue] = []
    @Published private(set) var loadErrorDescription: String?

    private let dataSource: PathlyDataSource

    init(dataSource: PathlyDataSource? = nil, autoLoad: Bool = true) {
        self.dataSource = dataSource ?? BundledJSONDataSource()

        if autoLoad {
            reload()
        }
    }

    func reload() {
        do {
            let dataset = try dataSource.load()
            opportunities = dataset.opportunities
            places = dataset.places
            organizations = dataset.organizations
            opportunityLocations = dataset.opportunityLocations
            validationIssues = DatasetValidator.validate(dataset)
            loadErrorDescription = nil

            #if DEBUG
            print(
                "Pathly data loaded: \(opportunities.count) opportunities, "
                + "\(places.count) places, \(organizations.count) organizations, "
                + "\(opportunityLocations.count) opportunity-location links."
            )
            for issue in validationIssues {
                print("Pathly data \(issue.severity.rawValue): \(issue.description)")
            }
            #endif
        } catch {
            opportunities = []
            places = []
            organizations = []
            opportunityLocations = []
            validationIssues = []
            loadErrorDescription = error.localizedDescription

            #if DEBUG
            print("Pathly data load failed: \(error.localizedDescription)")
            #endif
        }
    }
}

enum DataStoreError: LocalizedError {
    case missingResource(String)
    case unreadableResource(String, Error)
    case invalidResource(String, Error)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing bundled data resource: \(name). Confirm target membership and Copy Bundle Resources."
        case .unreadableResource(let name, let error):
            return "Could not read \(name): \(error.localizedDescription)"
        case .invalidResource(let name, let error):
            return "Could not decode \(name): \(Self.describe(error))"
        }
    }

    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .dataCorrupted(let context):
            return "\(context.debugDescription) at \(path(context.codingPath))"
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(path(context.codingPath))"
        case .typeMismatch(let type, let context):
            return "Expected \(type) at \(path(context.codingPath)): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing \(type) value at \(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        let value = codingPath.map(\.stringValue).joined(separator: ".")
        return value.isEmpty ? "root" : value
    }
}

enum PathlyDateCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            guard let date = date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected a valid YYYY-MM-DD date, received '\(string)'."
                )
            }
            return date
        }
        return decoder
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static func date(from string: String) -> Date? {
        guard string.count == 10, let midnightUTC = formatter.date(from: string) else {
            return nil
        }
        // These fields are calendar dates, not instants. Noon UTC preserves the
        // intended YYYY-MM-DD across every U.S. time zone when views format Date.
        let date = midnightUTC.addingTimeInterval(12 * 60 * 60)
        return formatter.string(from: date) == string ? date : nil
    }
}

enum DataValidationSeverity: String {
    case warning
    case error
}

struct DataValidationIssue: Identifiable, Equatable {
    let severity: DataValidationSeverity
    let dataset: String
    let recordID: String?
    let code: String
    let message: String

    var id: String {
        [dataset, recordID ?? "dataset", code, message].joined(separator: "|")
    }

    var description: String {
        let record = recordID.map { " [\($0)]" } ?? ""
        return "\(dataset)\(record): \(message)"
    }
}

enum DatasetValidator {
    private static let usStateCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
    ]

    static func validate(_ dataset: PathlyDataset) -> [DataValidationIssue] {
        var issues: [DataValidationIssue] = []

        validateUniqueIDs(dataset.opportunities.map(\.id), dataset: "opportunities", into: &issues)
        validateUniqueIDs(dataset.places.map(\.id), dataset: "places", into: &issues)
        validateUniqueIDs(dataset.organizations.map(\.id), dataset: "organizations", into: &issues)
        validateUniqueIDs(dataset.opportunityLocations.map(\.id), dataset: "opportunity_locations", into: &issues)

        let organizationIDs = Set(dataset.organizations.map(\.id))
        let opportunityIDs = Set(dataset.opportunities.map(\.id))
        let placeIDs = Set(dataset.places.map(\.id))

        for organization in dataset.organizations {
            validateID(organization.id, prefix: "org_", dataset: "organizations", into: &issues)
            validateName(organization.name, id: organization.id, dataset: "organizations", into: &issues)
            validateURL(organization.website, field: "website", id: organization.id, dataset: "organizations", into: &issues)
            validateCountry(organization.country, id: organization.id, dataset: "organizations", into: &issues)
        }

        for opportunity in dataset.opportunities {
            validateID(opportunity.id, prefix: "opp_", dataset: "opportunities", into: &issues)
            validateName(opportunity.name, id: opportunity.id, dataset: "opportunities", into: &issues)

            if let organizationID = opportunity.organizationID,
               !organizationIDs.contains(organizationID) {
                add(.error, "opportunities", opportunity.id, "missing_organization", "organization_id references missing record '\(organizationID)'.", to: &issues)
            }

            validateRange(opportunity.minGrade, opportunity.maxGrade, field: "grade", valid: 1...12, id: opportunity.id, into: &issues)
            validateRange(opportunity.minAge, opportunity.maxAge, field: "age", valid: 0...120, id: opportunity.id, into: &issues)
            validatePositiveRange(opportunity.minTeamSize, opportunity.maxTeamSize, field: "team size", id: opportunity.id, into: &issues)

            validateURL(opportunity.officialURL, field: "official_url", id: opportunity.id, dataset: "opportunities", into: &issues)
            validateURL(opportunity.applicationURL, field: "application_url", id: opportunity.id, dataset: "opportunities", into: &issues)
            validateURL(opportunity.sourceURL, field: "source_url", id: opportunity.id, dataset: "opportunities", into: &issues)

            validateStates(opportunity.eligibleStates, id: opportunity.id, into: &issues)
            for country in opportunity.eligibleCountries {
                validateCountry(country, id: opportunity.id, dataset: "opportunities", into: &issues)
            }

            if let applicationOpen = opportunity.applicationOpen,
               let deadline = opportunity.deadline,
               applicationOpen > deadline {
                add(.error, "opportunities", opportunity.id, "invalid_application_dates", "application_open is after deadline.", to: &issues)
            }

            if let eventStart = opportunity.eventStart,
               let eventEnd = opportunity.eventEnd,
               eventStart > eventEnd {
                add(.error, "opportunities", opportunity.id, "invalid_event_dates", "event_start is after event_end.", to: &issues)
            }

            if opportunity.format == .online && !opportunity.onlineAvailable {
                add(.warning, "opportunities", opportunity.id, "format_conflict", "format is Online but online_available is false.", to: &issues)
            }
        }

        for place in dataset.places {
            validateID(place.id, prefix: "place_", dataset: "places", into: &issues)
            validateName(place.name, id: place.id, dataset: "places", into: &issues)

            if let organizationID = place.organizationID,
               !organizationIDs.contains(organizationID) {
                add(.error, "places", place.id, "missing_organization", "organization_id references missing record '\(organizationID)'.", to: &issues)
            }

            if let latitude = place.latitude, !(-90...90).contains(latitude) {
                add(.error, "places", place.id, "invalid_latitude", "latitude must be between -90 and 90.", to: &issues)
            }
            if let longitude = place.longitude, !(-180...180).contains(longitude) {
                add(.error, "places", place.id, "invalid_longitude", "longitude must be between -180 and 180.", to: &issues)
            }

            validateURL(place.website, field: "website", id: place.id, dataset: "places", into: &issues)
            validateCountry(place.country, id: place.id, dataset: "places", into: &issues)

            if place.country == "US" {
                if let state = place.state, !usStateCodes.contains(state) {
                    add(.error, "places", place.id, "invalid_state", "US places must use a two-letter USPS state code.", to: &issues)
                } else if place.state == nil {
                    add(.warning, "places", place.id, "missing_state", "US place is missing a state and requires review.", to: &issues)
                }
            }
        }

        for relationship in dataset.opportunityLocations {
            if !opportunityIDs.contains(relationship.opportunityID) {
                add(.error, "opportunity_locations", relationship.id, "missing_opportunity", "opportunity_id references missing record '\(relationship.opportunityID)'.", to: &issues)
            }
            if !placeIDs.contains(relationship.placeID) {
                add(.error, "opportunity_locations", relationship.id, "missing_place", "place_id references missing record '\(relationship.placeID)'.", to: &issues)
            }
        }

        return issues
    }

    private static func validateUniqueIDs(_ ids: [String], dataset: String, into issues: inout [DataValidationIssue]) {
        var seen: Set<String> = []
        for id in ids where !seen.insert(id).inserted {
            add(.error, dataset, id, "duplicate_id", "Duplicate ID.", to: &issues)
        }
    }

    private static func validateID(_ id: String, prefix: String, dataset: String, into issues: inout [DataValidationIssue]) {
        let pattern = "^\(NSRegularExpression.escapedPattern(for: prefix))[0-9]{6}$"
        if id.range(of: pattern, options: .regularExpression) == nil {
            add(.error, dataset, id, "invalid_id", "ID must match \(prefix) followed by six digits.", to: &issues)
        }
    }

    private static func validateName(_ name: String, id: String, dataset: String, into issues: inout [DataValidationIssue]) {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(.error, dataset, id, "missing_name", "name cannot be empty.", to: &issues)
        }
    }

    private static func validateRange(_ minimum: Int?, _ maximum: Int?, field: String, valid: ClosedRange<Int>, id: String, into issues: inout [DataValidationIssue]) {
        if let minimum, !valid.contains(minimum) {
            add(.error, "opportunities", id, "invalid_\(field)_minimum", "min_\(field) is outside \(valid.lowerBound)...\(valid.upperBound).", to: &issues)
        }
        if let maximum, !valid.contains(maximum) {
            add(.error, "opportunities", id, "invalid_\(field)_maximum", "max_\(field) is outside \(valid.lowerBound)...\(valid.upperBound).", to: &issues)
        }
        if let minimum, let maximum, minimum > maximum {
            add(.error, "opportunities", id, "invalid_\(field)_range", "min_\(field) is greater than max_\(field).", to: &issues)
        }
    }

    private static func validatePositiveRange(_ minimum: Int?, _ maximum: Int?, field: String, id: String, into issues: inout [DataValidationIssue]) {
        if let minimum, minimum < 1 {
            add(.error, "opportunities", id, "invalid_team_minimum", "Minimum \(field) must be positive.", to: &issues)
        }
        if let maximum, maximum < 1 {
            add(.error, "opportunities", id, "invalid_team_maximum", "Maximum \(field) must be positive.", to: &issues)
        }
        if let minimum, let maximum, minimum > maximum {
            add(.error, "opportunities", id, "invalid_team_range", "Minimum \(field) is greater than maximum \(field).", to: &issues)
        }
    }

    private static func validateURL(_ url: URL?, field: String, id: String, dataset: String, into issues: inout [DataValidationIssue]) {
        guard let url else { return }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            add(.error, dataset, id, "invalid_url", "\(field) must be an absolute HTTP or HTTPS URL.", to: &issues)
            return
        }
    }

    private static func validateStates(_ states: [String], id: String, into issues: inout [DataValidationIssue]) {
        if states.contains("ALL") && states.count > 1 {
            add(.error, "opportunities", id, "invalid_states", "eligible_states cannot combine ALL with state codes.", to: &issues)
        }
        for state in states where state != "ALL" && !usStateCodes.contains(state) {
            add(.error, "opportunities", id, "invalid_state", "Unrecognized USPS state code '\(state)'.", to: &issues)
        }
    }

    private static func validateCountry(_ country: String, id: String, dataset: String, into issues: inout [DataValidationIssue]) {
        if country.count != 2 || country != country.uppercased() {
            add(.error, dataset, id, "invalid_country", "Country must use an uppercase two-letter ISO code.", to: &issues)
        }
    }

    private static func add(
        _ severity: DataValidationSeverity,
        _ dataset: String,
        _ recordID: String?,
        _ code: String,
        _ message: String,
        to issues: inout [DataValidationIssue]
    ) {
        issues.append(
            DataValidationIssue(
                severity: severity,
                dataset: dataset,
                recordID: recordID,
                code: code,
                message: message
            )
        )
    }
}

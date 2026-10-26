import Combine
import Foundation

/// The single source of truth for onboarding answers and editable settings.
/// Custom decoding keeps profiles saved by older app versions compatible as fields evolve.
struct UserProfile: Codable, Equatable {
    var name = ""
    var grade: String?
    var age = 14
    var zipCode = ""
    var resolvedLocation = ""
    var stateCode = ""
    var latitude: Double?
    var longitude: Double?
    var school = ""
    var interests: Set<String> = []
    var opportunityTypes: Set<String> = []
    var isOpenToAnything = false
    var skills: Set<String> = []
    var travelRadius = 25
    var showsOnline = true
    var showsInPerson = true
    var costPreference = "Any"
    var teamPreference = "Either"
    var challengePreference = "Balanced"

    var firstName: String? {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.split(separator: " ").first.map(String.init)
    }

    var gradeLevel: Int? {
        grade == "College" ? 13 : grade.flatMap(Int.init)
    }

    var hasDiscoveryLocation: Bool {
        (zipCode.count == 5 && zipCode.allSatisfy { "0123456789".contains($0) })
            || !resolvedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func clearResolvedLocation() {
        resolvedLocation = ""
        stateCode = ""
        latitude = nil
        longitude = nil
    }

    var inferredStateCode: String? {
        if let code = USStateLookup.code(for: stateCode) { return code }
        return USStateLookup.code(in: resolvedLocation)
    }

    enum CodingKeys: String, CodingKey {
        case name, grade, age, zipCode, resolvedLocation, stateCode, latitude, longitude
        case school, interests, opportunityTypes, isOpenToAnything, skills, travelRadius
        case showsOnline, showsInPerson, costPreference, teamPreference, challengePreference
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        grade = try values.decodeIfPresent(String.self, forKey: .grade)
        age = try values.decodeIfPresent(Int.self, forKey: .age) ?? 14
        zipCode = try values.decodeIfPresent(String.self, forKey: .zipCode) ?? ""
        resolvedLocation = try values.decodeIfPresent(String.self, forKey: .resolvedLocation) ?? ""
        stateCode = try values.decodeIfPresent(String.self, forKey: .stateCode) ?? ""
        latitude = try values.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try values.decodeIfPresent(Double.self, forKey: .longitude)
        school = try values.decodeIfPresent(String.self, forKey: .school) ?? ""
        interests = try values.decodeIfPresent(Set<String>.self, forKey: .interests) ?? []
        opportunityTypes = try values.decodeIfPresent(Set<String>.self, forKey: .opportunityTypes) ?? []
        isOpenToAnything = try values.decodeIfPresent(Bool.self, forKey: .isOpenToAnything) ?? false
        skills = try values.decodeIfPresent(Set<String>.self, forKey: .skills) ?? []
        travelRadius = try values.decodeIfPresent(Int.self, forKey: .travelRadius) ?? 25
        showsOnline = try values.decodeIfPresent(Bool.self, forKey: .showsOnline) ?? true
        showsInPerson = try values.decodeIfPresent(Bool.self, forKey: .showsInPerson) ?? true
        costPreference = try values.decodeIfPresent(String.self, forKey: .costPreference) ?? "Any"
        teamPreference = try values.decodeIfPresent(String.self, forKey: .teamPreference) ?? "Either"
        challengePreference = try values.decodeIfPresent(String.self, forKey: .challengePreference) ?? "Balanced"
    }
}

enum USStateLookup {
    static let namesToCodes: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
        "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
        "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
        "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
        "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
        "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
        "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
        "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC"
    ]

    static let validCodes = Set(namesToCodes.values)

    static func code(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.uppercased()
        if validCodes.contains(uppercased) { return uppercased }
        return namesToCodes[trimmed.lowercased()]
    }

    static func code(in location: String) -> String? {
        let lowercased = location.lowercased()
        if let match = namesToCodes.first(where: { lowercased.contains($0.key) }) {
            return match.value
        }

        let tokens = location
            .uppercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        return tokens.first(where: validCodes.contains)
    }
}

@MainActor
final class OnboardingStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { save() }
    }

    private static let profileKey = "pathly.userProfile.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.profileKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = savedProfile
        } else {
            profile = UserProfile()
        }
    }

    func toggle(_ value: String, in keyPath: WritableKeyPath<UserProfile, Set<String>>) {
        if profile[keyPath: keyPath].contains(value) {
            profile[keyPath: keyPath].remove(value)
        } else {
            profile[keyPath: keyPath].insert(value)
        }
    }

    func reset() {
        defaults.removeObject(forKey: Self.profileKey)
        profile = UserProfile()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.profileKey)
    }
}

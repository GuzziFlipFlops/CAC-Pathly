import Foundation

/// Canonical vocabularies shared by Pathly's bundled data and future backends.
/// Add new values deliberately and document them in Data/README.md before use.
enum OpportunityCategory: String, Codable, CaseIterable, Hashable {
    case competition = "Competition"
    case hackathon = "Hackathon"
    case research = "Research"
    case internship = "Internship"
    case scholarship = "Scholarship"
    case program = "Program"
    case camp = "Camp"
    case workshop = "Workshop"
    case event = "Event"
    case volunteering = "Volunteering"
    case leadership = "Leadership"
    case club = "Club"
    case fellowship = "Fellowship"
    case grant = "Grant"
}

enum InterestTag: String, Codable, CaseIterable, Hashable {
    case computerScience = "Computer Science"
    case programming = "Programming"
    case artificialIntelligence = "Artificial Intelligence"
    case cybersecurity = "Cybersecurity"
    case robotics = "Robotics"
    case engineering = "Engineering"
    case electronics = "Electronics"
    case science = "Science"
    case biology = "Biology"
    case chemistry = "Chemistry"
    case physics = "Physics"
    case medicine = "Medicine"
    case mathematics = "Mathematics"
    case space = "Space"
    case environment = "Environment"
    case business = "Business"
    case entrepreneurship = "Entrepreneurship"
    case finance = "Finance"
    case economics = "Economics"
    case writing = "Writing"
    case journalism = "Journalism"
    case art = "Art"
    case design = "Design"
    case music = "Music"
    case film = "Film"
    case gameDevelopment = "Game Development"
    case publicPolicy = "Public Policy"
    case debate = "Debate"
    case communityService = "Community Service"
}

enum OpportunityFormat: String, Codable, CaseIterable, Hashable {
    case online = "Online"
    case inPerson = "In-Person"
    case hybrid = "Hybrid"
}

enum GeographicScope: String, Codable, CaseIterable, Hashable {
    case local = "Local"
    case county = "County"
    case congressionalDistrict = "Congressional District"
    case state = "State"
    case regional = "Regional"
    case national = "National"
    case international = "International"
    case anywhere = "Anywhere"
}

enum OpportunityStatus: String, Codable, CaseIterable, Hashable {
    case open = "Open"
    case upcoming = "Upcoming"
    case closed = "Closed"
    case expired = "Expired"
    case unknown = "Unknown"
}

enum PlaceStatus: String, Codable, CaseIterable, Hashable {
    case active = "Active"
    case temporarilyClosed = "Temporarily Closed"
    case closed = "Closed"
    case unknown = "Unknown"
}

enum RecognitionLevel: String, Codable, CaseIterable, Hashable {
    case local = "Local"
    case regional = "Regional"
    case state = "State"
    case strong = "Strong"
    case high = "High"
    case exceptional = "Exceptional"
}

enum SelectivityLevel: String, Codable, CaseIterable, Hashable {
    case open = "Open"
    case competitive = "Competitive"
    case selective = "Selective"
    case highlySelective = "Highly Selective"
    case unknown = "Unknown"
}

enum DifficultyLevel: String, Codable, CaseIterable, Hashable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    case unknown = "Unknown"
}

enum TeamType: String, Codable, CaseIterable, Hashable {
    case individual = "Individual"
    case team = "Team"
    case individualOrTeam = "Individual or Team"
}

enum Recurrence: String, Codable, CaseIterable, Hashable {
    case oneTime = "One-Time"
    case annual = "Annual"
    case seasonal = "Seasonal"
    case monthly = "Monthly"
    case recurring = "Recurring"
    case unknown = "Unknown"
}

enum PlaceType: String, Codable, CaseIterable, Hashable {
    case library = "Library"
    case makerspace = "Makerspace"
    case fabLab = "Fab Lab"
    case museum = "Museum"
    case scienceCenter = "Science Center"
    case university = "University"
    case roboticsClub = "Robotics Club"
    case communityCenter = "Community Center"
    case hackerspace = "Hackerspace"
    case observatory = "Observatory"
    case innovationLab = "Innovation Lab"
    case youthCenter = "Youth Center"
}

enum OrganizationType: String, Codable, CaseIterable, Hashable {
    case company = "Company"
    case nonprofit = "Nonprofit"
    case government = "Government"
    case university = "University"
    case school = "School"
    case library = "Library"
    case foundation = "Foundation"
    case communityOrganization = "Community Organization"
    case professionalOrganization = "Professional Organization"
    case other = "Other"
}

import Foundation

/// A physical educational resource that can be displayed on Pathly's map.
struct Place: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let organizationID: String?
    let imageAssetName: String?

    let placeType: PlaceType
    let description: String?

    let address: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String

    let latitude: Double?
    let longitude: Double?

    let website: URL?
    let phone: String?

    let freeAccess: Bool?
    let membershipRequired: Bool?
    let ageRestrictions: String?

    let resourceTags: [String]
    let interestTags: [InterestTag]

    let verified: Bool
    let lastVerified: Date
    let status: PlaceStatus

    enum CodingKeys: String, CodingKey {
        case id, name, description, address, city, state, zip, country
        case latitude, longitude, website, phone, verified, status
        case organizationID = "organization_id"
        case imageAssetName = "image_asset_name"
        case placeType = "place_type"
        case freeAccess = "free_access"
        case membershipRequired = "membership_required"
        case ageRestrictions = "age_restrictions"
        case resourceTags = "resource_tags"
        case interestTags = "interest_tags"
        case lastVerified = "last_verified"
    }
}

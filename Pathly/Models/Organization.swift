import Foundation

/// An organizer or owner referenced by opportunities and places.
struct Organization: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let organizationType: OrganizationType
    let logoAssetName: String?
    let website: URL?
    let country: String
    let description: String?
    let verified: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, website, country, description, verified
        case organizationType = "organization_type"
        case logoAssetName = "logo_asset_name"
    }
}

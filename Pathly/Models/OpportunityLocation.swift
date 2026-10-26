import Foundation

/// A many-to-many link between an opportunity and a physical place.
struct OpportunityLocation: Codable, Identifiable, Hashable {
    let opportunityID: String
    let placeID: String

    var id: String { "\(opportunityID)::\(placeID)" }

    enum CodingKeys: String, CodingKey {
        case opportunityID = "opportunity_id"
        case placeID = "place_id"
    }
}

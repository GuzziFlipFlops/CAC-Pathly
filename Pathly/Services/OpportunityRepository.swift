import Foundation

/// Read boundary used by recommendations and Pathly AI. A remote/local-cache source can replace DataStore later.
@MainActor
protocol OpportunityRepository: AnyObject {
    var opportunities: [Opportunity] { get }
    var places: [Place] { get }
    var organizations: [Organization] { get }
    var opportunityLocations: [OpportunityLocation] { get }

    func opportunity(id: String) -> Opportunity?
    func place(id: String) -> Place?
}

extension DataStore: OpportunityRepository {
    func opportunity(id: String) -> Opportunity? {
        opportunities.first { $0.id == id }
    }

    func place(id: String) -> Place? {
        places.first { $0.id == id }
    }
}

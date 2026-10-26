import Foundation

/// Presentation-only data for the temporary Home cards.
/// Canonical database records use `Models/Opportunity.swift`.
struct OpportunityCardModel: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let organization: String
    let match: String
    let highlight: String?
    let tags: [String]
    let detail: String
    let location: String
    let symbol: String
}

enum MockOpportunities {
    static let samples = [
        OpportunityCardModel(
            title: "Congressional App Challenge",
            organization: "U.S. House of Representatives",
            match: "Excellent Match",
            highlight: "High Recognition",
            tags: ["Competition", "App Development"],
            detail: "Deadline: Oct. 26",
            location: "Online · Delaware",
            symbol: "apps.iphone"
        ),
        OpportunityCardModel(
            title: "Hack Club Program",
            organization: "Hack Club",
            match: "Excellent Match",
            highlight: "Free",
            tags: ["Programming", "Online"],
            detail: "Applications open",
            location: "Online",
            symbol: "chevron.left.forwardslash.chevron.right"
        ),
        OpportunityCardModel(
            title: "Robotics Discovery Workshop",
            organization: "Delaware STEM Council",
            match: "Good Match",
            highlight: nil,
            tags: ["Robotics", "Workshop"],
            detail: "Saturday · 10:00 AM",
            location: "8 miles away",
            symbol: "gearshape.2.fill"
        )
    ]
}

import Foundation

enum OnboardingData {
    static let grades = ["6", "7", "8", "9", "10", "11", "12", "College"]

    static let interests = [
        "Robotics", "Programming", "Artificial Intelligence", "Engineering",
        "Science", "Medicine", "Math", "Business", "Finance", "Entrepreneurship",
        "Cybersecurity", "Writing", "Art & Design", "Environment", "Space",
        "Game Development"
    ]

    static let interestIcons: [String: String] = [
        "Robotics": "gearshape.2.fill",
        "Programming": "chevron.left.forwardslash.chevron.right",
        "Artificial Intelligence": "sparkles",
        "Engineering": "wrench.adjustable.fill",
        "Science": "atom",
        "Medicine": "cross.case.fill",
        "Math": "function",
        "Business": "briefcase.fill",
        "Finance": "chart.line.uptrend.xyaxis",
        "Entrepreneurship": "lightbulb.fill",
        "Cybersecurity": "lock.shield.fill",
        "Writing": "pencil.line",
        "Art & Design": "paintpalette.fill",
        "Environment": "leaf.fill",
        "Space": "moon.stars.fill",
        "Game Development": "gamecontroller.fill"
    ]

    static let opportunityTypes = [
        "Competitions", "Hackathons", "Research", "Internships", "Scholarships",
        "Programs & Camps", "Volunteering", "Workshops & Events", "Clubs", "Makerspaces"
    ]

    static let opportunityIcons: [String: String] = [
        "Competitions": "trophy.fill",
        "Hackathons": "chevron.left.forwardslash.chevron.right",
        "Research": "doc.text.magnifyingglass",
        "Internships": "briefcase.fill",
        "Scholarships": "medal.fill",
        "Programs & Camps": "tent.fill",
        "Volunteering": "heart.fill",
        "Workshops & Events": "calendar.badge.clock",
        "Clubs": "person.3.fill",
        "Makerspaces": "hammer.fill"
    ]

    static let skills = [
        "Python", "Java", "Swift", "C/C++", "Web Development", "App Development",
        "CAD", "3D Printing", "Electronics", "Robotics", "Research",
        "Public Speaking", "Graphic Design", "Video Editing"
    ]

    static let travelRadii = [5, 10, 25, 50]
    static let costPreferences = ["Free only", "Under $50", "Under $200", "Any"]
    static let teamPreferences = ["Individual", "Team", "Either"]
}

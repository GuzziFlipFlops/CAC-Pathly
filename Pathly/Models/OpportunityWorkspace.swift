import Foundation

enum OpportunityWorkStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case notStarted
    case inProgress
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .finished: "Finished"
        }
    }

    var symbol: String {
        switch self {
        case .notStarted: "circle"
        case .inProgress: "clock.fill"
        case .finished: "checkmark.circle.fill"
        }
    }
}

struct OpportunityWorkspaceTask: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

/// The student's progress through a curated roadmap. Step IDs come from `RoadmapTemplate`;
/// the template itself stays in code so guide updates never overwrite checkmarks.
struct RoadmapProgress: Codable, Hashable {
    let templateID: String
    let templateVersion: Int
    /// Template step IDs in order, captured when the roadmap was created.
    let stepIDs: [String]
    var completedStepIDs: Set<String>
    let createdAt: Date

    var completedCount: Int { stepIDs.lazy.filter { completedStepIDs.contains($0) }.count }
}

/// User-specific progress for one canonical opportunity.
/// The opportunity itself remains in the bundled catalog and is never duplicated here.
struct OpportunityWorkspace: Codable, Identifiable, Hashable {
    let id: String
    var status: OpportunityWorkStatus
    var tasks: [OpportunityWorkspaceTask]
    var notes: String
    let createdAt: Date
    var updatedAt: Date
    /// Decoded with `decodeIfPresent`, so workspaces saved before roadmaps existed still load.
    var roadmap: RoadmapProgress? = nil

    var completedTaskCount: Int {
        tasks.lazy.filter(\.isCompleted).count
    }

    /// With a roadmap, progress follows the roadmap; the starter checklist stays as optional extras.
    var completedStepCount: Int { roadmap?.completedCount ?? completedTaskCount }
    var totalStepCount: Int { roadmap?.stepIDs.count ?? tasks.count }

    var progress: Double {
        guard totalStepCount > 0 else { return status == .finished ? 1 : 0 }
        return Double(completedStepCount) / Double(totalStepCount)
    }
}

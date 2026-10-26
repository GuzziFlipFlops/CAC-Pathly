import Combine
import Foundation

/// Persists personal opportunity progress separately from canonical catalog data.
@MainActor
final class OpportunityWorkspaceStore: ObservableObject {
    @Published private(set) var workspaces: [String: OpportunityWorkspace] = [:]
    @Published private(set) var persistenceErrorDescription: String?

    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func workspace(for opportunityID: String) -> OpportunityWorkspace? {
        workspaces[opportunityID]
    }

    @discardableResult
    func startWorkspace(for opportunity: Opportunity) -> OpportunityWorkspace {
        if let existing = workspaces[opportunity.id] { return existing }
        let now = Date()
        let workspace = OpportunityWorkspace(
            id: opportunity.id,
            status: .notStarted,
            tasks: Self.starterTasks(for: opportunity),
            notes: "",
            createdAt: now,
            updatedAt: now
        )
        workspaces[opportunity.id] = workspace
        persist()
        return workspace
    }

    func setStatus(_ status: OpportunityWorkStatus, for opportunityID: String) {
        update(opportunityID) { workspace in
            workspace.status = status
        }
    }

    func toggleTask(_ taskID: UUID, for opportunityID: String) {
        update(opportunityID) { workspace in
            guard let index = workspace.tasks.firstIndex(where: { $0.id == taskID }) else { return }
            workspace.tasks[index].isCompleted.toggle()
            if workspace.status == .notStarted, workspace.tasks[index].isCompleted {
                workspace.status = .inProgress
            }
        }
    }

    func addTask(title: String, to opportunityID: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        update(opportunityID) { workspace in
            workspace.tasks.append(OpportunityWorkspaceTask(title: cleanTitle))
            if workspace.status == .finished {
                workspace.status = .inProgress
            }
        }
    }

    func removeTask(_ taskID: UUID, from opportunityID: String) {
        update(opportunityID) { workspace in
            workspace.tasks.removeAll { $0.id == taskID }
        }
    }

    /// Materializes a roadmap once. Notes, checkmarks, and the student's own tasks are kept;
    /// only the untouched generic starter checklist is cleared, since the roadmap replaces it.
    func createRoadmap(from template: RoadmapTemplate, for opportunityID: String) {
        update(opportunityID) { workspace in
            guard workspace.roadmap == nil else { return }
            let untouchedStarter = workspace.tasks.allSatisfy {
                !$0.isCompleted && Self.starterTaskTitles.contains($0.title)
            }
            if untouchedStarter {
                workspace.tasks = []
            }
            workspace.roadmap = RoadmapProgress(
                templateID: template.id,
                templateVersion: template.version,
                stepIDs: template.stepIDs,
                completedStepIDs: [],
                createdAt: Date()
            )
            if workspace.status == .notStarted {
                workspace.status = .inProgress
            }
        }
    }

    func toggleRoadmapStep(_ stepID: String, for opportunityID: String) {
        update(opportunityID) { workspace in
            guard var roadmap = workspace.roadmap, roadmap.stepIDs.contains(stepID) else { return }
            if roadmap.completedStepIDs.contains(stepID) {
                roadmap.completedStepIDs.remove(stepID)
            } else {
                roadmap.completedStepIDs.insert(stepID)
                if workspace.status == .notStarted {
                    workspace.status = .inProgress
                }
            }
            workspace.roadmap = roadmap
        }
    }

    func updateNotes(_ notes: String, for opportunityID: String) {
        update(opportunityID) { workspace in
            workspace.notes = notes
        }
    }

    private func update(_ opportunityID: String, mutation: (inout OpportunityWorkspace) -> Void) {
        guard var workspace = workspaces[opportunityID] else { return }
        mutation(&workspace)
        workspace.updatedAt = Date()
        workspaces[opportunityID] = workspace
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try decoder.decode([OpportunityWorkspace].self, from: data)
            workspaces = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
            persistenceErrorDescription = nil
        } catch {
            persistenceErrorDescription = "Pathly couldn't load saved opportunity progress."
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let ordered = workspaces.values.sorted { $0.id < $1.id }
            try encoder.encode(ordered).write(to: storageURL, options: .atomic)
            persistenceErrorDescription = nil
        } catch {
            persistenceErrorDescription = "Pathly couldn't save opportunity progress."
        }
    }

    private static func defaultStorageURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("Pathly", isDirectory: true)
            .appendingPathComponent("opportunity_workspaces_v1.json")
    }

    private static let starterTaskTitles: Set<String> = [
        "Confirm eligibility on the official page",
        "Review the official rules and requirements",
        "Save the deadline and plan your timeline",
        "Open the application and create an account if needed",
        "Gather the required materials",
        "Draft and review your submission",
        "Submit through the official application"
    ]

    private static func starterTasks(for opportunity: Opportunity) -> [OpportunityWorkspaceTask] {
        var titles = [
            "Confirm eligibility on the official page",
            "Review the official rules and requirements"
        ]
        if opportunity.deadline != nil {
            titles.append("Save the deadline and plan your timeline")
        }
        if opportunity.applicationURL != nil {
            titles.append("Open the application and create an account if needed")
        }
        titles.append(contentsOf: [
            "Gather the required materials",
            "Draft and review your submission",
            "Submit through the official application"
        ])
        return titles.map { OpportunityWorkspaceTask(title: $0) }
    }
}

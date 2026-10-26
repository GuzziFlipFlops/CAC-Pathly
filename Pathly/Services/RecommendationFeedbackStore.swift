import Combine
import Foundation

enum RecommendationFeedback: String, Codable {
    case interested
    case notInterested
}

struct RecommendationFeedbackSnapshot: Codable, Equatable, Sendable {
    var feedbackByID: [String: RecommendationFeedback] = [:]
    var seenCounts: [String: Int] = [:]
    var lastSurpriseIDs: [String] = []
}

/// User-specific recommendation signals. These never modify canonical catalog records.
@MainActor
final class RecommendationFeedbackStore: ObservableObject {
    @Published private(set) var snapshot: RecommendationFeedbackSnapshot

    private static let storageKey = "pathly.recommendationFeedback.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(RecommendationFeedbackSnapshot.self, from: data) {
            snapshot = stored
        } else {
            snapshot = RecommendationFeedbackSnapshot()
        }
    }

    func feedback(for id: String) -> RecommendationFeedback? {
        snapshot.feedbackByID[id]
    }

    func setFeedback(_ feedback: RecommendationFeedback, for id: String) {
        if snapshot.feedbackByID[id] == feedback {
            snapshot.feedbackByID.removeValue(forKey: id)
        } else {
            snapshot.feedbackByID[id] = feedback
        }
        persist()
    }

    func applyFeedback(_ feedback: RecommendationFeedback, for id: String) {
        snapshot.feedbackByID[id] = feedback
        persist()
    }

    func markShown(_ ids: [String], asSurprise: Bool = false) {
        for id in ids {
            snapshot.seenCounts[id, default: 0] += 1
        }
        if asSurprise {
            snapshot.lastSurpriseIDs = ids
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

#if DEBUG
/// Recording-only ordering. It selects from eligible IDs supplied by the real engine.
/// It never creates records, edits the profile, or changes production ranking.
struct GuidedDemoSequence {
    static let settingsKey = "pathly.guidedDemo.enabled"
    static let conradID = "opp_000099"
    static let appChallengeID = "opp_000116"
    /// County fair → DVSF → ISEF. Found through Ask Pathly in the video, so Home doesn't show them first.
    static let isefPathIDs: Set<String> = ["opp_000387", "opp_000031", "opp_000094"]
    private(set) var hasRevealedConrad = false

    var excludedHomeIDs: Set<String> {
        let reserved = Self.isefPathIDs.union([Self.appChallengeID])
        return hasRevealedConrad ? reserved : reserved.union([Self.conradID])
    }

    mutating func firstRoll(eligibleIDs: [String], count: Int = 4) -> [String]? {
        guard !hasRevealedConrad, count > 0, eligibleIDs.contains(Self.conradID) else { return nil }
        hasRevealedConrad = true
        let reserved = excludedHomeIDs
        return [Self.conradID] + eligibleIDs.filter {
            $0 != Self.conradID && !reserved.contains($0)
        }.prefix(count - 1)
    }
}
#endif

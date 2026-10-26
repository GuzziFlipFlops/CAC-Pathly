import Foundation

/// A predefined assistant reply with the status lines shown before it.
struct PathlyScriptedReply {
    let statuses: [String]
    let text: String
    var opportunityIDs: [String] = []
    var quickReplies: [String] = []
    var sources: String? = nil
    var savesOpportunityIDs: [String] = []
}

#if DEBUG
/// Recording-only conversation for the CAC demo video. Replies are written in advance;
/// they are not generated. Release builds don't contain this file's logic.
/// Every other message goes through the normal catalog search.
enum PathlyDemoScript {
    static let isefID = "opp_000094"
    static let countyFairID = "opp_000387"
    static let dvsfID = "opp_000031"
    static let stsID = "opp_000096"
    static let jshsID = "opp_000097"

    /// Off by default: Ask Pathly uses Apple Foundation Models. Only the video recording turned this on
    /// (launch with PATHLY_SCRIPTED_DEMO=1 to re-record).
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["PATHLY_SCRIPTED_DEMO"] == "1"
    }

    static func reply(to message: String, catalogCount: Int) -> PathlyScriptedReply? {
        let text = message.lowercased().replacingOccurrences(of: "’", with: "'")
        let words = Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        let mentionsISEF = words.contains("isef")

        if mentionsISEF, words.contains("save") || words.contains("add") {
            return PathlyScriptedReply(
                statuses: ["Saving to your list…"],
                text: "Saved **Regeneron ISEF**. Open it in Saved and tap **Build my roadmap** to plan all three stages.",
                savesOpportunityIDs: [isefID]
            )
        }

        if mentionsISEF {
            return PathlyScriptedReply(
                statuses: [
                    "Searching Pathly's database…",
                    "Searching the web…",
                    "Reading societyforscience.org…",
                    "Checking Delaware fairs on dvsf.org…"
                ],
                text: """
                You can't apply to ISEF directly. You qualify by placing at science fairs, and from Delaware the path looks like this:

                **1. New Castle County Science Fair**: Mar 9, 2027 at Delaware Tech
                **2. Delaware Valley Science Fairs**: Apr 7, 2027. It sends about 12 students to ISEF.
                **3. Regeneron ISEF**: May 8–14, 2027 in Los Angeles

                AI projects usually fit the Robotics & Intelligent Machines or Systems Software categories. The county fair is about four months away, so now is the time to pick a question and find a teacher sponsor.
                """,
                opportunityIDs: [countyFairID, dvsfID, isefID],
                quickReplies: ["Save ISEF to my list"],
                sources: "societyforscience.org · dvsf.org · checked Oct 24, 2026"
            )
        }

        let wantsCommitment = ["worthwhile", "lock", "prestigious", "prestige", "serious", "months"]
            .contains { words.contains($0) }
        if wantsCommitment {
            return PathlyScriptedReply(
                statuses: [
                    "Searching Pathly's database…",
                    "Filtering \(catalogCount) opportunities for research and AI…",
                    "Ranking by prestige and time commitment…"
                ],
                text: """
                If you're ready to commit, these are the most respected research competitions that fit you:

                **Regeneron ISEF** is the largest pre-college science fair in the world. You qualify through local fairs, so you can start this school year.

                **JSHS** lets you present your research at a regional symposium.

                **Regeneron Science Talent Search** is worth planning for senior year.
                """,
                opportunityIDs: [isefID, stsID, jshsID],
                quickReplies: ["Tell me more about ISEF"]
            )
        }

        let mentionsAI = words.contains("ai") || text.contains("artificial intelligence")
        if words.contains("research"), mentionsAI {
            return PathlyScriptedReply(
                statuses: ["Reading your profile…", "Searching Pathly's database…"],
                text: """
                Research and AI is a strong combination, and there's a lot to choose from. Two quick questions first:

                **1. How much does prestige matter?** Is this for experience, or something that stands out on applications?
                **2. How much time can you give it?** A weekend, or a few months?
                """,
                quickReplies: ["I want it to be worthwhile, and I'm willing to lock in", "Something quick, just for experience"]
            )
        }

        return nil
    }
}
#endif

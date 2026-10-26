import Foundation
import FoundationModels

@MainActor
final class AppleFoundationModelProvider: PathlyLanguageModelProvider {
    private let model = SystemLanguageModel.default
    private let index: PathlyAIToolIndex
    private let profileSummary: String

    private var isForcedUnavailableForTesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PATHLY_AI_DISABLE_MODEL"] == "1"
        #else
        false
        #endif
    }

    var availability: PathlyAIAvailability {
        if isForcedUnavailableForTesting {
            return .unavailable("On-device generation is disabled for this test. Pathly database search is still available.")
        }
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("Apple Intelligence isn’t supported on this device. Pathly database search is still available.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Apple Intelligence is turned off. Pathly database search is still available.")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple’s on-device model is still preparing. Pathly database search is available in the meantime.")
        case .unavailable:
            return .unavailable("Apple’s on-device model is unavailable. Pathly database search is still available.")
        }
    }

    init(index: PathlyAIToolIndex, profileSummary: String) {
        self.index = index
        self.profileSummary = profileSummary
    }

    func respond(to request: LanguageModelProviderRequest) async throws -> LanguageModelProviderReply {
        guard model.isAvailable, !isForcedUnavailableForTesting else {
            throw PathlyAIProviderError.unavailable
        }

        let collector = PathlyAIToolResultCollector()
        let tools: [any Tool] = [
            SearchPathlyCatalogTool(index: index, collector: collector),
            GetPathlyItemTool(index: index, collector: collector),
            GetSavedItemsTool(index: index, collector: collector)
        ]
        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: """
            You are Pathly AI, the student opportunity-discovery advisor built into Pathly.
            Help middle-school and high-school students find and compare opportunities, scholarships,
            competitions, research, internships, programs, events, clubs, and nearby educational resources.
            You are not a general-purpose chatbot. Briefly redirect unrelated requests to what Pathly can find.
            Pathly's tools and prefetched records are authoritative for facts. Never invent an opportunity,
            deadline, eligibility rule, location, cost, award, organization, URL, or status. Say "unknown"
            when the stored record is unknown. Swift has already applied hard eligibility; do not override it.
            You may give concise general opportunity-development advice, but factual claims about a record
            must appear in the supplied record. Answer directly, explain the most useful distinction in two
            to four short sentences, and let the app's cards carry the details. Avoid generic praise or filler.

            Current Pathly profile context:
            \(profileSummary)
            """
        )
        session.prewarm()
        let response = try await session.respond(
            to: """
            Student request: \(request.message)

            Compact conversation state (retain these temporary refinements):
            \(request.conversationState)

            Pathly already searched before generation. Explain only these canonical results. You may use
            a tool if a detail, saved item, or refined catalog lookup is genuinely needed:
            \(request.prefetchedCatalogContext)
            """
        )
        let ids = await collector.snapshot()
        return LanguageModelProviderReply(
            text: response.content,
            opportunityIDs: Array(ids.opportunityIDs.prefix(8)),
            placeIDs: Array(ids.placeIDs.prefix(8))
        )
    }
}

enum PathlyAIProviderError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "The on-device language model is unavailable."
    }
}

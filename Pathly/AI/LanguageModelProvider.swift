import Foundation

enum PathlyAIAvailability: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var message: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

struct LanguageModelProviderReply: Equatable {
    let text: String
    let opportunityIDs: [String]
    let placeIDs: [String]
}

struct LanguageModelProviderRequest: Equatable {
    let message: String
    let conversationState: String
    let prefetchedCatalogContext: String
}

/// Provider boundary so a future model can replace Apple Intelligence without changing retrieval.
@MainActor
protocol PathlyLanguageModelProvider: AnyObject {
    var availability: PathlyAIAvailability { get }
    func respond(to request: LanguageModelProviderRequest) async throws -> LanguageModelProviderReply
}

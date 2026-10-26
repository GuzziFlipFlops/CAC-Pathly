import Combine
import Foundation

/// Persists stable catalog IDs locally until Pathly has an account-backed sync service.
@MainActor
final class SavedItemsStore: ObservableObject {
    @Published private(set) var itemIDs: [String]

    private static let storageKey = "pathly.savedCatalogItemIDs.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        itemIDs = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    func contains(_ id: String) -> Bool {
        itemIDs.contains(id)
    }

    func toggle(_ id: String) {
        if let index = itemIDs.firstIndex(of: id) {
            itemIDs.remove(at: index)
        } else {
            itemIDs.insert(id, at: 0)
        }
        persist()
    }

    func save(_ id: String) {
        guard !itemIDs.contains(id) else { return }
        itemIDs.insert(id, at: 0)
        persist()
    }

    func remove(_ id: String) {
        guard let index = itemIDs.firstIndex(of: id) else { return }
        itemIDs.remove(at: index)
        persist()
    }

    private func persist() {
        defaults.set(itemIDs, forKey: Self.storageKey)
    }
}

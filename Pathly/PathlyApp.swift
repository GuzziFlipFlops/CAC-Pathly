//
//  PathlyApp.swift
//  Pathly
//
//  Created by Ram Verma on 8/21/26.
//

import SwiftUI

@main
struct PathlyApp: App {
    @StateObject private var dataStore = DataStore()
    @StateObject private var savedItemsStore = SavedItemsStore()
    @StateObject private var recommendationFeedbackStore = RecommendationFeedbackStore()
    @StateObject private var discoveryStore = PathlyDiscoveryStore()
    @StateObject private var opportunityWorkspaceStore = OpportunityWorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(PathlyTheme.cyan)
                .environmentObject(dataStore)
                .environmentObject(savedItemsStore)
                .environmentObject(recommendationFeedbackStore)
                .environmentObject(discoveryStore)
                .environmentObject(opportunityWorkspaceStore)
        }
    }
}

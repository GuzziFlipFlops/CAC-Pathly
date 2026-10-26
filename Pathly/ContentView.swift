//
//  ContentView.swift
//  Pathly
//
//  Created by Ram Verma on 8/21/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("pathly.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var onboardingStore = OnboardingStore()

    private var isReviewingOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PATHLY_ONBOARDING_STEP"] != nil
        #else
        false
        #endif
    }

    private var isReviewingDashboard: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PATHLY_SHOW_HOME"] == "1"
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            if (hasCompletedOnboarding || isReviewingDashboard) && !isReviewingOnboarding {
                MainTabView(resetOnboarding: resetOnboarding)
                    .transition(.opacity)
            } else {
                OnboardingView(store: onboardingStore) {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .environmentObject(onboardingStore)
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["PATHLY_RESET_ONBOARDING"] == "1" {
                hasCompletedOnboarding = false
            }
            #endif
        }
    }

    private func resetOnboarding() {
        onboardingStore.reset()
        hasCompletedOnboarding = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

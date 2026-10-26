import SwiftUI

private enum OnboardingStep: Int {
    case welcome
    case gradeAndAge
    case interests
    case opportunityTypes
    case skills
    case formatPreferences
    case finalPreferences
    case matching
}

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var isMovingForward = true

    init(store: OnboardingStore, onComplete: @escaping () -> Void) {
        self.store = store
        self.onComplete = onComplete

        #if DEBUG
        let debugStep = ProcessInfo.processInfo.environment["PATHLY_ONBOARDING_STEP"]
            .flatMap(Int.init)
            .flatMap(OnboardingStep.init(rawValue:))
        _step = State(initialValue: debugStep ?? .welcome)
        #endif
    }

    var body: some View {
        ZStack {
            PathlyBackground()

            if step == .welcome {
                WelcomeView(onStart: moveForward)
                    .transition(pageTransition)
            } else if step == .matching {
                MatchingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                questionContainer
                    .transition(pageTransition)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var questionContainer: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ZStack {
                ScrollView {
                    currentStepView
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 660)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .id(step)
                .transition(pageTransition)
            }

            PrimaryButton(
                title: step == .finalPreferences ? "Build My Feed" : "Continue",
                icon: step == .finalPreferences ? "sparkles" : "arrow.right",
                isEnabled: canContinue,
                action: moveForward
            )
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(PathlyTheme.deepNavy.opacity(0.95))
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 14) {
            Button(action: moveBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(PathlyTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(PathlyTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            PathProgressView(progress: progress, totalSteps: 6)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .gradeAndAge:
            GradeAgeStep(profile: $store.profile)
        case .interests:
            InterestsStep(store: store)
        case .opportunityTypes:
            OpportunityTypesStep(store: store)
        case .skills:
            SkillsStep(store: store)
        case .formatPreferences:
            FormatPreferencesStep(profile: $store.profile)
        case .finalPreferences:
            FinalPreferencesStep(profile: $store.profile)
        default:
            EmptyView()
        }
    }

    private var progress: CGFloat {
        CGFloat(step.rawValue) / 6
    }

    private var canContinue: Bool {
        switch step {
        case .gradeAndAge:
            store.profile.grade != nil
        case .interests:
            !store.profile.interests.isEmpty
        case .opportunityTypes:
            store.profile.isOpenToAnything || !store.profile.opportunityTypes.isEmpty
        case .formatPreferences:
            store.profile.hasDiscoveryLocation
                && (store.profile.showsOnline || store.profile.showsInPerson)
        case .welcome, .skills, .finalPreferences, .matching:
            true
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func moveForward() {
        guard canContinue, let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        isMovingForward = true
        PathlyHaptics.impact()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            step = next
        }

        if next == .matching {
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.4)) {
                    onComplete()
                }
            }
        }
    }

    private func moveBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        isMovingForward = false
        PathlyHaptics.selection()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            step = previous
        }
    }
}

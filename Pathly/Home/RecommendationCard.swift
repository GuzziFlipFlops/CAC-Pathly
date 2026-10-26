import SwiftUI

struct RecommendationOpportunityCard: View {
    @EnvironmentObject private var feedbackStore: RecommendationFeedbackStore
    let recommendation: OpportunityRecommendation
    let organization: Organization?
    var showsFeedback = true

    var body: some View {
        VStack(spacing: 8) {
            ExploreResultLink(
                result: .opportunity(recommendation.opportunity, organization),
                contextBadges: recommendation.labels
            )

            if showsFeedback {
                HStack(spacing: 10) {
                    feedbackButton(.interested, title: "Interested", symbol: "hand.thumbsup")
                    feedbackButton(.notInterested, title: "Not for me", symbol: "hand.thumbsdown")
                }
            }
        }
    }

    private func feedbackButton(
        _ feedback: RecommendationFeedback,
        title: String,
        symbol: String
    ) -> some View {
        let isSelected = feedbackStore.feedback(for: recommendation.id) == feedback
        return Button {
            feedbackStore.setFeedback(feedback, for: recommendation.id)
            PathlyHaptics.selection()
        } label: {
            Label(title, systemImage: isSelected ? symbol + ".fill" : symbol)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? .white : PathlyDashboardTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    isSelected ? PathlyDashboardTheme.accent : PathlyDashboardTheme.surface,
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(PathlyDashboardTheme.border, lineWidth: isSelected ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RecommendationPlaceCard: View {
    let recommendation: PlaceRecommendation
    let organization: Organization?

    var body: some View {
        ExploreResultLink(
            result: .place(recommendation.place, organization),
            contextBadges: recommendation.labels
        )
    }
}

struct PathlySectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension PathlySectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

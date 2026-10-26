import SwiftUI

struct OpportunityCard: View {
    let opportunity: OpportunityCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: opportunity.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(PathlyDashboardTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(opportunity.title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(opportunity.organization)
                        .font(.subheadline)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Label(opportunity.match, systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(PathlyDashboardTheme.accent, in: Capsule())

                if let highlight = opportunity.highlight {
                    Text(highlight)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(PathlyDashboardTheme.accent.opacity(0.09), in: Capsule())
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(opportunity.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PathlyDashboardTheme.elevatedSurface, in: Capsule())
                }
            }

            Divider().overlay(PathlyDashboardTheme.border)

            HStack {
                Label(opportunity.detail, systemImage: "calendar")
                Spacer(minLength: 12)
                Label(opportunity.location, systemImage: "location")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(PathlyDashboardTheme.secondaryText)
        }
        .padding(18)
        .pathlyDashboardCard(cornerRadius: 24)
    }
}

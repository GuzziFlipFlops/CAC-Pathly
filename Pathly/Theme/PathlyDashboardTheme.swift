import SwiftUI

enum PathlyDashboardTheme {
    static let background = Color(red: 0.970, green: 0.978, blue: 0.990)
    static let surface = Color.white
    static let elevatedSurface = Color(red: 0.905, green: 0.945, blue: 0.985)
    static let accent = Color(red: 0.000, green: 0.610, blue: 0.735)
    static let softAccent = Color(red: 0.000, green: 0.455, blue: 0.585)
    static let primaryText = Color(red: 0.018, green: 0.075, blue: 0.180)
    static let secondaryText = Color(red: 0.310, green: 0.400, blue: 0.520)
    static let border = Color(red: 0.050, green: 0.150, blue: 0.285).opacity(0.10)
    static let shadow = Color(red: 0.015, green: 0.075, blue: 0.160).opacity(0.045)
}

struct PathlyDashboardBackground: View {
    var body: some View {
        ZStack {
            PathlyDashboardTheme.background

            RadialGradient(
                colors: [PathlyDashboardTheme.accent.opacity(0.035), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func pathlyDashboardCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(
                PathlyDashboardTheme.surface,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PathlyDashboardTheme.border, lineWidth: 1)
            }
            .shadow(color: PathlyDashboardTheme.shadow, radius: 10, y: 3)
    }
}

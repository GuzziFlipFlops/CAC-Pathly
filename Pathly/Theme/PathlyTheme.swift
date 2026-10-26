import SwiftUI

enum PathlyTheme {
    static let navy = Color(red: 0.018, green: 0.075, blue: 0.225)
    static let deepNavy = Color(red: 0.008, green: 0.031, blue: 0.105)
    static let surface = Color(red: 0.035, green: 0.115, blue: 0.285)
    static let elevatedSurface = Color(red: 0.055, green: 0.155, blue: 0.355)
    static let cyan = Color(red: 0.176, green: 0.827, blue: 0.918)
    static let softCyan = Color(red: 0.545, green: 0.939, blue: 0.976)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.650, green: 0.735, blue: 0.850)
    static let border = Color.white.opacity(0.12)
}

struct PathlyBackground: View {
    var body: some View {
        ZStack {
            PathlyTheme.deepNavy

            RadialGradient(
                colors: [PathlyTheme.cyan.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )

            LinearGradient(
                colors: [PathlyTheme.navy.opacity(0.75), PathlyTheme.deepNavy],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func pathlyCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(PathlyTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PathlyTheme.border, lineWidth: 1)
            }
    }
}

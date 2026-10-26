import SwiftUI

struct MatchingView: View {
    @State private var activeIndex = 0

    private let items = [
        ("Matching interests", "sparkles"),
        ("Checking eligibility", "checkmark.seal.fill"),
        ("Finding nearby opportunities", "location.fill")
    ]

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(PathlyTheme.cyan.opacity(0.12))
                    .frame(width: 132, height: 132)
                    .scaleEffect(activeIndex == items.count ? 1.16 : 1)

                Image(systemName: "sparkle")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(PathlyTheme.cyan)
                    .shadow(color: PathlyTheme.cyan.opacity(0.65), radius: 18)
            }

            VStack(spacing: 10) {
                Text("Finding opportunities for you…")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PathlyTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Building your first Pathly feed")
                    .foregroundStyle(PathlyTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 14) {
                        Image(systemName: index < activeIndex ? "checkmark.circle.fill" : item.1)
                            .foregroundStyle(index <= activeIndex ? PathlyTheme.cyan : PathlyTheme.secondaryText)
                            .frame(width: 24)
                        Text(item.0)
                            .foregroundStyle(index <= activeIndex ? PathlyTheme.primaryText : PathlyTheme.secondaryText)
                        Spacer()
                    }
                    .opacity(index <= activeIndex ? 1 : 0.45)
                }
            }
            .padding(22)
            .pathlyCard()
        }
        .padding(24)
        .frame(maxWidth: 560)
        .task {
            for index in 1...items.count {
                try? await Task.sleep(for: .milliseconds(430))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    activeIndex = index
                }
            }
        }
    }
}

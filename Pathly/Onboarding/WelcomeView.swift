import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("WelcomeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(hasAppeared ? 1.015 : 1.04)
                    .opacity(hasAppeared ? 1 : 0)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.28),
                        .init(color: PathlyTheme.deepNavy.opacity(0.16), location: 0.44),
                        .init(color: PathlyTheme.deepNavy.opacity(0.88), location: 0.62),
                        .init(color: PathlyTheme.deepNavy, location: 0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(proxy.size.height * 0.48, 330))

                        VStack(spacing: 15) {
                            Text("Find opportunities that fit you.")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PathlyTheme.primaryText)
                                .multilineTextAlignment(.center)

                            Text("Competitions, research, hackathons, events, makerspaces, scholarships, and more — personalized for you.")
                                .font(.body)
                                .foregroundStyle(PathlyTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 12)

                        PrimaryButton(title: "Get Started", icon: "arrow.right") {
                            PathlyHaptics.impact()
                            onStart()
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 26)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) {
                hasAppeared = true
            }
        }
    }
}

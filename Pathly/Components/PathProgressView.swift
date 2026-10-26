import SwiftUI

struct PathProgressView: View {
    let progress: CGFloat
    var totalSteps = 7

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var isComplete: Bool {
        clampedProgress >= 1
    }

    var body: some View {
        GeometryReader { proxy in
            let destination = PathProgressShape.destination(in: proxy.frame(in: .local))

            ZStack(alignment: .topLeading) {
                PathProgressShape()
                    .stroke(
                        PathlyTheme.elevatedSurface,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )

                PathProgressShape()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [PathlyTheme.softCyan, PathlyTheme.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: PathlyTheme.cyan.opacity(0.5), radius: 5)

                Image(systemName: "sparkle")
                    .font(.system(size: isComplete ? 25 : 20, weight: .bold))
                    .foregroundStyle(isComplete ? PathlyTheme.cyan : PathlyTheme.elevatedSurface)
                    .shadow(color: isComplete ? PathlyTheme.cyan.opacity(0.9) : .clear, radius: 9)
                    .scaleEffect(isComplete ? 1.08 : 1)
                    .position(destination)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 44)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: clampedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(Int((clampedProgress * CGFloat(totalSteps)).rounded())) of \(totalSteps) steps")
    }
}

private struct PathProgressShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + 3, y: rect.midY + 5)
        let firstTurn = CGPoint(x: rect.width * 0.30, y: rect.midY - 7)
        let secondTurn = CGPoint(x: rect.width * 0.57, y: rect.midY + 7)
        let destination = Self.destination(in: rect)

        path.move(to: start)
        path.addCurve(
            to: firstTurn,
            control1: CGPoint(x: rect.width * 0.10, y: rect.midY + 15),
            control2: CGPoint(x: rect.width * 0.20, y: rect.midY - 15)
        )
        path.addCurve(
            to: secondTurn,
            control1: CGPoint(x: rect.width * 0.39, y: rect.midY - 2),
            control2: CGPoint(x: rect.width * 0.46, y: rect.midY + 15)
        )
        path.addCurve(
            to: destination,
            control1: CGPoint(x: rect.width * 0.68, y: rect.midY),
            control2: CGPoint(x: rect.width * 0.79, y: rect.midY - 13)
        )
        return path
    }

    static func destination(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.maxX - 15, y: rect.midY - 3)
    }
}

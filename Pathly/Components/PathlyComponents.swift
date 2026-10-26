import SwiftUI
import UIKit

enum PathlyHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                if let icon {
                    Image(systemName: icon)
                }
            }
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(PathlyTheme.deepNavy)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                isEnabled ? PathlyTheme.cyan : PathlyTheme.secondaryText.opacity(0.38),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: isEnabled ? PathlyTheme.cyan.opacity(0.2) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

struct SelectionChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            PathlyHaptics.selection()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? PathlyTheme.softCyan : PathlyTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                isSelected ? PathlyTheme.cyan.opacity(0.15) : PathlyTheme.surface.opacity(0.88),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isSelected ? PathlyTheme.cyan.opacity(0.9) : PathlyTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
            .scaleEffect(isSelected ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ChoiceCard: View {
    let title: String
    var subtitle: String?
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            PathlyHaptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(isSelected ? PathlyTheme.softCyan : PathlyTheme.cyan)
                        .frame(width: 38, height: 38)
                        .background(PathlyTheme.cyan.opacity(isSelected ? 0.18 : 0.1), in: Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(PathlyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? PathlyTheme.cyan : PathlyTheme.secondaryText)
            }
            .foregroundStyle(PathlyTheme.primaryText)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(
                isSelected ? PathlyTheme.cyan.opacity(0.12) : PathlyTheme.surface.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? PathlyTheme.cyan.opacity(0.9) : PathlyTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct StepHeading: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let eyebrow {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                        .font(.caption.weight(.bold))

                    Text(eyebrow.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(1.4)
                }
                .foregroundStyle(PathlyTheme.cyan)
            }

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(PathlyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct SelectionTile: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            PathlyHaptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(isSelected ? PathlyTheme.softCyan : PathlyTheme.cyan)
                        .frame(width: 34, height: 34)
                        .background(PathlyTheme.cyan.opacity(isSelected ? 0.17 : 0.09), in: Circle())

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(PathlyTheme.cyan)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyTheme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.66)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(
                isSelected ? PathlyTheme.cyan.opacity(0.13) : PathlyTheme.surface.opacity(0.86),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? PathlyTheme.cyan.opacity(0.9) : PathlyTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )

        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }

            points.append(cursor)
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, cursor.x + size.width)
            cursor.x += size.width + spacing
        }

        return (CGSize(width: min(contentWidth, maxWidth), height: cursor.y + rowHeight), points)
    }
}

struct PathlyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(PathlyTheme.primaryText)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(PathlyTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PathlyTheme.border, lineWidth: 1)
            }
    }
}

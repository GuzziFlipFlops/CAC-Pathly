import SwiftUI

struct GradeAgeStep: View {
    @Binding var profile: UserProfile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeading(
                eyebrow: "Your profile",
                title: "What grade are you in?",
                subtitle: "This helps us check grade-based eligibility."
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OnboardingData.grades, id: \.self) { grade in
                    gradeButton(grade)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("How old are you?")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyTheme.primaryText)

                    Text("This is optional context—you can change it later.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(PathlyTheme.secondaryText)
                }

                HStack(spacing: 18) {
                    ageButton(systemName: "minus", isEnabled: profile.age > 10) {
                        profile.age -= 1
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 1) {
                        Text("\(profile.age)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(PathlyTheme.primaryText)

                        Text("years old")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(PathlyTheme.secondaryText)
                    }
                    .contentTransition(.numericText(value: Double(profile.age)))

                    Spacer(minLength: 0)

                    ageButton(systemName: "plus", isEnabled: profile.age < 24) {
                        profile.age += 1
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 88)
                .pathlyCard(cornerRadius: 20)
            }

            DisclosureGroup {
                VStack(spacing: 12) {
                    TextField("Your name (optional)", text: $profile.name)
                        .textContentType(.givenName)
                        .textFieldStyle(PathlyTextFieldStyle())
                    TextField("School name (optional)", text: $profile.school)
                        .textContentType(.organizationName)
                        .textFieldStyle(PathlyTextFieldStyle())
                }
                .padding(.top, 12)
            } label: {
                Text("Name & school · optional")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PathlyTheme.secondaryText)
            }
            .tint(PathlyTheme.cyan)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: profile.age)
    }

    private func gradeButton(_ grade: String) -> some View {
        let isSelected = profile.grade == grade

        return Button {
            PathlyHaptics.selection()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                profile.grade = grade
            }
        } label: {
            Text(grade)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? PathlyTheme.deepNavy : PathlyTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    isSelected ? PathlyTheme.cyan : PathlyTheme.surface.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? PathlyTheme.softCyan : PathlyTheme.border, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func ageButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PathlyHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(isEnabled ? PathlyTheme.cyan : PathlyTheme.secondaryText.opacity(0.35))
                .frame(width: 48, height: 48)
                .background(PathlyTheme.elevatedSurface.opacity(isEnabled ? 0.72 : 0.3), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct OnboardingLocationPicker: View {
    @Binding var profile: UserProfile
    @StateObject private var locationService = LocationService()
    @FocusState private var zipIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where are you right now?")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyTheme.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(PathlyTheme.cyan)

                    TextField("ZIP code", text: $profile.zipCode,
                              prompt: Text("ZIP code").foregroundStyle(PathlyTheme.secondaryText))
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .focused($zipIsFocused)
                        .accessibilityIdentifier("onboarding.zip")
                        .accessibilityLabel("ZIP code")
                        .foregroundStyle(PathlyTheme.primaryText)

                    if locationService.isWorking {
                        ProgressView()
                            .tint(PathlyTheme.cyan)
                    } else if zipIsFocused {
                        Button("Done") { zipIsFocused = false }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PathlyTheme.cyan)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .pathlyCard(cornerRadius: 16)

                Button {
                    zipIsFocused = false
                    PathlyHaptics.impact()
                    locationService.requestCurrentLocation()
                } label: {
                    Label("Use my current location", systemImage: "location.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyTheme.cyan)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PathlyTheme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(locationService.isWorking)
            }

            if !profile.resolvedLocation.isEmpty {
                Label(profile.resolvedLocation, systemImage: "checkmark.circle.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PathlyTheme.softCyan)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PathlyTheme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let errorMessage = locationService.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(PathlyTheme.secondaryText)
            }

            Text("A ZIP code is enough. No street address needed.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(PathlyTheme.secondaryText)
        }
        .onChange(of: profile.zipCode) { _, newValue in
            let filtered = String(newValue.filter { "0123456789".contains($0) }.prefix(5))
            if filtered != newValue {
                profile.zipCode = filtered
                return
            }
            // A device-location result updates ZIP and coordinates together.
            guard locationService.selection?.postalCode != filtered else { return }
            locationService.cancelLookup()
            profile.clearResolvedLocation()
        }
        .task(id: profile.zipCode) {
            let zip = profile.zipCode
            guard zip.count == 5, profile.resolvedLocation.isEmpty else { return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, profile.zipCode == zip else { return }
                locationService.resolve(zipCode: zip)
            } catch { }
        }
        .onChange(of: locationService.selection) { _, selection in
            guard let selection else { return }
            if !selection.postalCode.isEmpty { profile.zipCode = selection.postalCode }
            profile.resolvedLocation = selection.name
            profile.stateCode = selection.stateCode
            profile.latitude = selection.latitude
            profile.longitude = selection.longitude
        }
        .onDisappear { locationService.cancelLookup() }
    }
}

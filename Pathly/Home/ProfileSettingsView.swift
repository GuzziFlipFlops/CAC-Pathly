import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var profileStore: OnboardingStore
    let resetOnboarding: () -> Void

    @StateObject private var locationService = LocationService()
    @State private var customSkill = ""
    @FocusState private var customSkillIsFocused: Bool
    #if DEBUG
    @AppStorage(GuidedDemoSequence.settingsKey) private var guidedDemoEnabled = true
    #endif

    private var profile: Binding<UserProfile> { $profileStore.profile }

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            ScrollView {
                VStack(spacing: 16) {
                    profileSection
                    interestsSection
                    skillsSection
                    opportunityTypesSection
                    preferencesSection

                    #if DEBUG
                    SettingsSection(title: "Development", symbol: "hammer.fill") {
                        Toggle("Guided demo sequence", isOn: $guidedDemoEnabled)
                            .tint(PathlyDashboardTheme.accent)
                        Text("First Home dice roll reveals Conrad; Congressional App Challenge stays in Explore for search-and-save. Relaunch or switch this off and on to reset. Normal eligibility still applies. This setting is available only in development builds.")
                            .font(.caption)
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        Button(role: .destructive, action: resetOnboarding) {
                            Label("Reset onboarding and profile", systemImage: "arrow.counterclockwise")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                    #endif
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 36)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profileStore.profile.zipCode) { _, newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(5))
            if filtered != newValue { profileStore.profile.zipCode = filtered }
            if filtered.count == 5 { locationService.resolve(zipCode: filtered) }
        }
        .onChange(of: locationService.postalCode) { _, value in
            if !value.isEmpty { profileStore.profile.zipCode = value }
        }
        .onChange(of: locationService.resolvedLocation) { _, value in
            if !value.isEmpty { profileStore.profile.resolvedLocation = value }
        }
        .onChange(of: locationService.stateCode) { _, value in
            profileStore.profile.stateCode = value
        }
        .onChange(of: locationService.latitude) { _, value in
            profileStore.profile.latitude = value
        }
        .onChange(of: locationService.longitude) { _, value in
            profileStore.profile.longitude = value
        }
    }

    private var profileSection: some View {
        SettingsSection(title: "Profile", symbol: "person.crop.circle") {
            SettingsTextField(title: "Name", prompt: "Your name", text: profile.name)

            VStack(alignment: .leading, spacing: 10) {
                Text("Grade")
                    .settingsFieldLabel()
                FlowLayout(spacing: 8) {
                    ForEach(OnboardingData.grades, id: \.self) { grade in
                        SettingsChip(title: grade, isSelected: profileStore.profile.grade == grade) {
                            profileStore.profile.grade = grade
                        }
                    }
                }
            }

            Stepper(value: profile.age, in: 10...24) {
                HStack {
                    Text("Age").settingsFieldLabel()
                    Spacer()
                    Text("\(profileStore.profile.age)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                }
            }
            .tint(PathlyDashboardTheme.accent)

            SettingsTextField(title: "School", prompt: "School name (optional)", text: profile.school)

            VStack(alignment: .leading, spacing: 10) {
                Text("Location").settingsFieldLabel()
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(PathlyDashboardTheme.accent)
                    TextField("ZIP code", text: profile.zipCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                    if locationService.isWorking { ProgressView().tint(PathlyDashboardTheme.accent) }
                }
                .settingsFieldSurface()

                Button {
                    locationService.requestCurrentLocation()
                    PathlyHaptics.impact()
                } label: {
                    Label("Use current location", systemImage: "location.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PathlyDashboardTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if !profileStore.profile.resolvedLocation.isEmpty {
                    Label(profileStore.profile.resolvedLocation, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                }
                if let error = locationService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }
            }
        }
    }

    private var interestsSection: some View {
        SettingsSection(title: "Interests", symbol: "sparkles") {
            Text("These shape recommendations but never hide the full Explore catalog.")
                .font(.footnote)
                .foregroundStyle(PathlyDashboardTheme.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(OnboardingData.interests, id: \.self) { interest in
                    SettingsChip(
                        title: interest,
                        symbol: OnboardingData.interestIcons[interest],
                        isSelected: profileStore.profile.interests.contains(interest)
                    ) {
                        profileStore.toggle(interest, in: \UserProfile.interests)
                    }
                }
            }
        }
    }

    private var skillsSection: some View {
        SettingsSection(title: "Skills", symbol: "wrench.and.screwdriver") {
            if profileStore.profile.skills.isEmpty {
                Text("Add skills to improve skill-based recommendations.")
                    .font(.footnote)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(profileStore.profile.skills.sorted(), id: \.self) { skill in
                        Button {
                            profileStore.profile.skills.remove(skill)
                            PathlyHaptics.selection()
                        } label: {
                            Label(skill, systemImage: "xmark")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(PathlyDashboardTheme.softAccent)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 38)
                                .background(PathlyDashboardTheme.accent.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(skill)")
                    }
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(OnboardingData.skills.filter { !profileStore.profile.skills.contains($0) }, id: \.self) { skill in
                    SettingsChip(title: skill, isSelected: false) {
                        profileStore.profile.skills.insert(skill)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add a custom skill", text: $customSkill)
                    .textInputAutocapitalization(.words)
                    .focused($customSkillIsFocused)
                    .onSubmit(addSkill)
                    .settingsFieldSurface()
                Button(action: addSkill) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(trimmedSkill.isEmpty)
                .opacity(trimmedSkill.isEmpty ? 0.45 : 1)
            }
        }
    }

    private var opportunityTypesSection: some View {
        SettingsSection(title: "Opportunity types", symbol: "square.grid.2x2") {
            SettingsChip(title: "Open to anything", symbol: "sparkles", isSelected: profileStore.profile.isOpenToAnything) {
                profileStore.profile.isOpenToAnything.toggle()
                if profileStore.profile.isOpenToAnything { profileStore.profile.opportunityTypes.removeAll() }
            }

            FlowLayout(spacing: 8) {
                ForEach(OnboardingData.opportunityTypes, id: \.self) { type in
                    SettingsChip(title: type, isSelected: profileStore.profile.opportunityTypes.contains(type)) {
                        profileStore.profile.isOpenToAnything = false
                        profileStore.toggle(type, in: \UserProfile.opportunityTypes)
                    }
                }
            }
        }
    }

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences", symbol: "slider.horizontal.3") {
            Toggle("Show online opportunities", isOn: profile.showsOnline)
            Toggle("Show in-person opportunities", isOn: profile.showsInPerson)

            VStack(alignment: .leading, spacing: 8) {
                Text("Travel distance").settingsFieldLabel()
                Picker("Travel distance", selection: profile.travelRadius) {
                    ForEach(OnboardingData.travelRadii, id: \.self) { radius in
                        Text(radius == 50 ? "50+ mi" : "\(radius) mi").tag(radius)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsPicker(title: "Cost", selection: profile.costPreference, values: OnboardingData.costPreferences)
            SettingsPicker(title: "Team preference", selection: profile.teamPreference, values: OnboardingData.teamPreferences)
            SettingsPicker(
                title: "Challenge level",
                selection: profile.challengePreference,
                values: ["Comfortable", "Balanced", "Challenge Me"]
            )
        }
        .tint(PathlyDashboardTheme.accent)
    }

    private var trimmedSkill: String {
        customSkill.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addSkill() {
        guard !trimmedSkill.isEmpty else { return }
        profileStore.profile.skills.insert(trimmedSkill)
        customSkill = ""
        customSkillIsFocused = false
        PathlyHaptics.impact()
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: symbol)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathlyDashboardCard(cornerRadius: 22)
    }
}

private struct SettingsTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).settingsFieldLabel()
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.words)
                .settingsFieldSurface()
        }
    }
}

private struct SettingsPicker: View {
    let title: String
    @Binding var selection: String
    let values: [String]

    var body: some View {
        HStack {
            Text(title).settingsFieldLabel()
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(values, id: \.self) { Text($0).tag($0) }
            }
            .tint(PathlyDashboardTheme.softAccent)
        }
        .frame(minHeight: 44)
    }
}

struct SettingsChip: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            PathlyHaptics.selection()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? .white : PathlyDashboardTheme.primaryText)
            .padding(.horizontal, 11)
            .frame(minHeight: 40)
            .background(isSelected ? PathlyDashboardTheme.accent : PathlyDashboardTheme.elevatedSurface, in: Capsule())
            .overlay { Capsule().stroke(PathlyDashboardTheme.border, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    func settingsFieldLabel() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(PathlyDashboardTheme.secondaryText)
    }

    func settingsFieldSurface() -> some View {
        padding(.horizontal, 13)
            .frame(minHeight: 48)
            .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(PathlyDashboardTheme.border, lineWidth: 1) }
    }
}

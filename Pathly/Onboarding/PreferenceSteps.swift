import SwiftUI

struct InterestsStep: View {
    @ObservedObject var store: OnboardingStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeading(
                eyebrow: "Your interests",
                title: "What are you interested in?",
                subtitle: "Choose as many as you like. We'll use these to shape your feed."
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OnboardingData.interests, id: \.self) { interest in
                    SelectionTile(
                        title: interest,
                        icon: OnboardingData.interestIcons[interest] ?? "sparkle",
                        isSelected: store.profile.interests.contains(interest)
                    ) {
                        store.toggle(interest, in: \UserProfile.interests)
                    }
                }
            }
        }
    }
}

struct OpportunityTypesStep: View {
    @ObservedObject var store: OnboardingStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeading(
                eyebrow: "Your goals",
                title: "What do you want to discover?",
                subtitle: "Pick specific opportunity types, or keep the whole path open."
            )

            ChoiceCard(
                title: "I'm open to anything",
                subtitle: "Show me possibilities across every category.",
                icon: "sparkles",
                isSelected: store.profile.isOpenToAnything
            ) {
                store.profile.isOpenToAnything.toggle()
                if store.profile.isOpenToAnything {
                    store.profile.opportunityTypes.removeAll()
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OnboardingData.opportunityTypes, id: \.self) { type in
                    SelectionTile(
                        title: type,
                        icon: OnboardingData.opportunityIcons[type] ?? "sparkle",
                        isSelected: store.profile.opportunityTypes.contains(type)
                    ) {
                        store.profile.isOpenToAnything = false
                        store.toggle(type, in: \UserProfile.opportunityTypes)
                    }
                }
            }
        }
    }
}

struct SkillsStep: View {
    @ObservedObject var store: OnboardingStore
    @State private var isAddingSkill = false
    @State private var customSkill = ""
    @FocusState private var customSkillIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeading(
                eyebrow: "Your toolkit",
                title: "What skills do you already have?",
                subtitle: "No ratings or résumé required. Select any that feel familiar."
            )

            FlowLayout(spacing: 10) {
                ForEach(availableSkills, id: \.self) { skill in
                    SelectionChip(
                        title: skill,
                        isSelected: store.profile.skills.contains(skill)
                    ) {
                        store.toggle(skill, in: \UserProfile.skills)
                    }
                }

                SelectionChip(title: "+ Add Skill", isSelected: isAddingSkill) {
                    isAddingSkill.toggle()
                    customSkillIsFocused = isAddingSkill
                }
            }

            if isAddingSkill {
                HStack(spacing: 10) {
                    TextField("Your skill", text: $customSkill)
                        .textInputAutocapitalization(.words)
                        .focused($customSkillIsFocused)
                        .textFieldStyle(PathlyTextFieldStyle())
                        .onSubmit(addCustomSkill)

                    Button(action: addCustomSkill) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(PathlyTheme.deepNavy)
                            .frame(width: 52, height: 52)
                            .background(PathlyTheme.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedCustomSkill.isEmpty)
                    .opacity(trimmedCustomSkill.isEmpty ? 0.5 : 1)
                    .accessibilityLabel("Add skill")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isAddingSkill)
    }

    private var availableSkills: [String] {
        let custom = store.profile.skills.filter { !OnboardingData.skills.contains($0) }
        return OnboardingData.skills + custom.sorted()
    }

    private var trimmedCustomSkill: String {
        customSkill.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addCustomSkill() {
        guard !trimmedCustomSkill.isEmpty else { return }
        store.profile.skills.insert(trimmedCustomSkill)
        customSkill = ""
        isAddingSkill = false
        customSkillIsFocused = false
        PathlyHaptics.impact()
    }
}

struct FormatPreferencesStep: View {
    @Binding var profile: UserProfile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeading(
                eyebrow: "Your range",
                title: "How far are you willing to go?"
            )

            OnboardingLocationPicker(profile: $profile)

            VStack(alignment: .leading, spacing: 10) {
            Text("Your travel distance")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyTheme.primaryText)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8),
                    count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
                ),
                spacing: 8
            ) {
                ForEach(OnboardingData.travelRadii, id: \.self) { radius in
                    Button {
                        PathlyHaptics.selection()
                        profile.travelRadius = radius
                    } label: {
                        VStack(spacing: 4) {
                            Text(radius == 50 ? "50+" : "\(radius)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Text("mi")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(profile.travelRadius == radius ? PathlyTheme.deepNavy : PathlyTheme.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            profile.travelRadius == radius ? PathlyTheme.cyan : PathlyTheme.surface,
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(radius == 50 ? "50 or more" : String(radius)) miles")
                    .accessibilityAddTraits(profile.travelRadius == radius ? .isSelected : [])
                }
            }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("How you'll participate")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyTheme.primaryText)

                VStack(spacing: 0) {
                preferenceToggle(
                    "Online",
                    icon: "globe.americas.fill",
                    isOn: $profile.showsOnline
                )

                Divider().overlay(PathlyTheme.border).padding(.leading, 46)

                preferenceToggle(
                    "In person",
                    icon: "person.2.fill",
                    isOn: $profile.showsInPerson
                )
                }
                .padding(.horizontal, 16)
                .pathlyCard()
            }

            if !profile.showsOnline && !profile.showsInPerson {
                Label("Turn on at least one format to see opportunities.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(PathlyTheme.softCyan)
            }
        }
    }

    private func preferenceToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PathlyTheme.primaryText)
        }
        .tint(PathlyTheme.cyan)
        .frame(minHeight: 54)
    }
}

struct FinalPreferencesStep: View {
    @Binding var profile: UserProfile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeading(
                eyebrow: "Final touches",
                title: "Make Pathly yours.",
                subtitle: "A few final preferences will fine-tune what rises to the top."
            )

            preferenceSection(
                title: "Cost",
                values: OnboardingData.costPreferences,
                columnCount: 2,
                selection: $profile.costPreference
            )
            preferenceSection(
                title: "Team preference",
                values: OnboardingData.teamPreferences,
                columnCount: 3,
                selection: $profile.teamPreference
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("What should we show you?")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyTheme.primaryText)

                ChoiceCard(
                    title: "Comfortable",
                    subtitle: "Mostly opportunities closely matching your current skills.",
                    icon: "checkmark.shield.fill",
                    isSelected: profile.challengePreference == "Comfortable"
                ) { profile.challengePreference = "Comfortable" }

                ChoiceCard(
                    title: "Balanced",
                    subtitle: "A mix of strong matches and opportunities that stretch you.",
                    icon: "slider.horizontal.3",
                    isSelected: profile.challengePreference == "Balanced"
                ) { profile.challengePreference = "Balanced" }

                ChoiceCard(
                    title: "Challenge Me",
                    subtitle: "Include ambitious options that may require learning new skills.",
                    icon: "arrow.up.right",
                    isSelected: profile.challengePreference == "Challenge Me"
                ) { profile.challengePreference = "Challenge Me" }
            }
        }
    }

    private func preferenceSection(
        title: String,
        values: [String],
        columnCount: Int,
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyTheme.primaryText)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : columnCount
                ),
                spacing: 10
            ) {
                ForEach(values, id: \.self) { value in
                    preferenceButton(value, selection: selection)
                }
            }
        }
    }

    private func preferenceButton(_ value: String, selection: Binding<String>) -> some View {
        let isSelected = selection.wrappedValue == value

        return Button {
            PathlyHaptics.selection()
            selection.wrappedValue = value
        } label: {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? PathlyTheme.softCyan : PathlyTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    isSelected ? PathlyTheme.cyan.opacity(0.15) : PathlyTheme.surface.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? PathlyTheme.cyan : PathlyTheme.border, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

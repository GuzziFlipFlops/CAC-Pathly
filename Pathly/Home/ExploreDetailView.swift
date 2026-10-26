import SwiftUI

struct OpportunityDetailView: View {
    @EnvironmentObject private var savedItems: SavedItemsStore
    let opportunity: Opportunity
    let organization: Organization?
    private let calendarService = CalendarService()
    @State private var isAddingToCalendar = false
    @State private var showsCalendarAlert = false
    @State private var calendarAlertMessage = ""

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DetailHero(
                        assetName: opportunity.imageAssetName ?? organization?.logoAssetName,
                        symbol: opportunity.category.detailSymbol,
                        eyebrow: opportunity.category.rawValue,
                        title: opportunity.name,
                        subtitle: organization?.name,
                        usesFullBleedArtwork: opportunity.imageAssetName != nil
                    )

                    DetailSection(title: "Overview", symbol: "text.alignleft") {
                        Text(opportunity.descriptionFull ?? opportunity.descriptionShort)
                            .detailBodyStyle()

                        if let subcategory = opportunity.subcategory {
                            DetailFact(label: "Type", value: subcategory)
                        }
                    }

                    DetailSection(title: "Eligibility", symbol: "checkmark.seal") {
                        DetailFact(label: "Grades", value: gradeRange)
                        DetailFact(label: "Ages", value: ageRange)
                        DetailFact(label: "Geographic scope", value: opportunity.geographicScope.rawValue)
                        DetailFact(label: "Eligible states", value: eligibleStates)
                        DetailFact(label: "Eligible countries", value: opportunity.eligibleCountries.joined(separator: ", "))

                        if let teamType = opportunity.teamType {
                            DetailFact(label: "Participation", value: teamType.rawValue)
                        }
                        if let teamSize {
                            DetailFact(label: "Team size", value: teamSize)
                        }
                        if let notes = opportunity.eligibilityNotes {
                            Text(notes)
                                .detailBodyStyle()
                                .padding(.top, 2)
                        }
                    }

                    DetailSection(title: "Schedule and logistics", symbol: "calendar") {
                        DetailFact(label: "Format", value: opportunity.format.rawValue)
                        DetailFact(label: "Online available", value: opportunity.onlineAvailable ? "Yes" : "No")
                        DetailFact(label: "Travel required", value: opportunity.travelRequired ? "Yes" : "No")
                        DetailFact(label: "Cost", value: costLabel)
                        DetailFact(label: "Financial aid", value: optionalBoolean(opportunity.financialAid))
                        DetailFact(label: "Applications open", value: formatted(opportunity.applicationOpen))
                        DetailFact(label: "Deadline", value: formatted(opportunity.deadline))
                        DetailFact(label: "Starts", value: formatted(opportunity.eventStart))
                        DetailFact(label: "Ends", value: formatted(opportunity.eventEnd))
                        DetailFact(label: "Recurrence", value: opportunity.recurring.rawValue)

                        if let prizeValue = opportunity.prizeValue {
                            DetailFact(label: "Awards", value: prizeValue)
                        }

                        if opportunity.deadline != nil {
                            Button {
                                addDeadlineToCalendar()
                            } label: {
                                HStack {
                                    if isAddingToCalendar {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "calendar.badge.plus")
                                    }
                                    Text(isAddingToCalendar ? "Adding deadline…" : "Add deadline to Calendar")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                                .background(
                                    PathlyDashboardTheme.accent,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isAddingToCalendar)
                            .padding(.top, 4)
                        }
                    }

                    DetailSection(title: "Skills and interests", symbol: "sparkles") {
                        DetailFact(label: "Difficulty", value: opportunity.difficultyLevel.rawValue)
                        DetailFact(label: "Selectivity", value: opportunity.selectivityLevel.rawValue)
                        if let recognition = opportunity.recognitionLevel {
                            DetailFact(label: "Recognition", value: recognition.rawValue)
                        }

                        if !opportunity.interestTags.isEmpty {
                            DetailTagGroup(
                                title: "Interests",
                                tags: opportunity.interestTags.map(\.rawValue)
                            )
                        }
                        if !opportunity.requiredSkills.isEmpty {
                            DetailTagGroup(title: "Required skills", tags: opportunity.requiredSkills)
                        }
                        if !opportunity.recommendedSkills.isEmpty {
                            DetailTagGroup(title: "Recommended skills", tags: opportunity.recommendedSkills)
                        }
                    }

                    DetailSection(title: "Official links", symbol: "link") {
                        DetailLink(title: "Official website", url: opportunity.officialURL)
                        if let applicationURL = opportunity.applicationURL {
                            DetailLink(title: "Apply", url: applicationURL, emphasized: true)
                        }
                        if opportunity.sourceURL != opportunity.officialURL {
                            DetailLink(title: "Verification source", url: opportunity.sourceURL)
                        }
                        DetailFact(label: "Last checked", value: formatted(opportunity.lastVerified))
                        DetailFact(label: "Current status", value: opportunity.status.rawValue)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 36)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Opportunity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                saveButton
            }
        }
        .alert("Calendar", isPresented: $showsCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
    }

    private var saveButton: some View {
        Button {
            savedItems.toggle(opportunity.id)
            PathlyHaptics.selection()
        } label: {
            Image(systemName: savedItems.contains(opportunity.id) ? "bookmark.fill" : "bookmark")
        }
        .accessibilityLabel(
            savedItems.contains(opportunity.id)
                ? "Remove from Saved"
                : "Save opportunity"
        )
    }

    private func addDeadlineToCalendar() {
        isAddingToCalendar = true
        Task {
            do {
                try await calendarService.addDeadline(for: opportunity)
                calendarAlertMessage = "The deadline was added to your default calendar with a reminder one day before."
                PathlyHaptics.success()
            } catch {
                calendarAlertMessage = error.localizedDescription
            }
            isAddingToCalendar = false
            showsCalendarAlert = true
        }
    }

    private var gradeRange: String? {
        rangeLabel(minimum: opportunity.minGrade, maximum: opportunity.maxGrade, prefix: "Grade ")
    }

    private var ageRange: String? {
        rangeLabel(minimum: opportunity.minAge, maximum: opportunity.maxAge, prefix: "")
    }

    private var eligibleStates: String {
        opportunity.eligibleStates == ["ALL"] ? "All U.S. states" : opportunity.eligibleStates.joined(separator: ", ")
    }

    private var teamSize: String? {
        rangeLabel(minimum: opportunity.minTeamSize, maximum: opportunity.maxTeamSize, prefix: "")
    }

    private var costLabel: String? {
        guard let cost = opportunity.costUSD else { return nil }
        if cost == 0 { return "Free" }
        return NSDecimalNumber(decimal: cost).doubleValue.formatted(.currency(code: "USD"))
    }
}

struct PlaceDetailView: View {
    @EnvironmentObject private var savedItems: SavedItemsStore
    let place: Place
    let organization: Organization?

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DetailHero(
                        assetName: place.imageAssetName ?? place.placeType.categoryAssetName,
                        symbol: place.placeType.detailSymbol,
                        eyebrow: place.placeType.rawValue,
                        title: place.name,
                        subtitle: organization?.name,
                        usesFullBleedArtwork: true
                    )

                    DetailSection(title: "About", symbol: "info.circle") {
                        if let description = place.description {
                            Text(description).detailBodyStyle()
                        }
                        DetailFact(label: "Status", value: place.status.rawValue)
                        DetailFact(label: "Verified record", value: place.verified ? "Yes" : "No")
                        DetailFact(label: "Last checked", value: formatted(place.lastVerified))
                    }

                    DetailSection(title: "Location", symbol: "location") {
                        if let address = place.address {
                            DetailFact(label: "Address", value: address)
                        }
                        DetailFact(label: "City", value: place.city)
                        DetailFact(label: "State", value: place.state)
                        DetailFact(label: "ZIP", value: place.zip)
                        DetailFact(label: "Country", value: place.country)

                        if let mapsURL {
                            DetailLink(title: "Open in Apple Maps", url: mapsURL, emphasized: true)
                        } else {
                            Text("A map pin has not been added for this place yet.")
                                .font(.footnote)
                                .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        }
                    }

                    DetailSection(title: "Access", symbol: "door.left.hand.open") {
                        DetailFact(label: "Free access", value: optionalBoolean(place.freeAccess))
                        DetailFact(label: "Membership required", value: optionalBoolean(place.membershipRequired))
                        if let ageRestrictions = place.ageRestrictions {
                            DetailFact(label: "Age restrictions", value: ageRestrictions)
                        }
                    }

                    if !place.resourceTags.isEmpty || !place.interestTags.isEmpty {
                        DetailSection(title: "Resources", symbol: "wrench.and.screwdriver") {
                            if !place.resourceTags.isEmpty {
                                DetailTagGroup(title: "Available resources", tags: place.resourceTags)
                            }
                            if !place.interestTags.isEmpty {
                                DetailTagGroup(title: "Related interests", tags: place.interestTags.map(\.rawValue))
                            }
                        }
                    }

                    if place.website != nil || place.phone != nil || organization?.website != nil {
                        DetailSection(title: "Contact", symbol: "link") {
                            if let website = place.website {
                                DetailLink(title: "Place website", url: website, emphasized: true)
                            }
                            if let organizationWebsite = organization?.website, organizationWebsite != place.website {
                                DetailLink(title: "Organization website", url: organizationWebsite)
                            }
                            if let phone = place.phone, let phoneURL = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                                DetailLink(title: phone, url: phoneURL)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 36)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Place")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    savedItems.toggle(place.id)
                    PathlyHaptics.selection()
                } label: {
                    Image(systemName: savedItems.contains(place.id) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(
                    savedItems.contains(place.id)
                        ? "Remove from Saved"
                        : "Save place"
                )
            }
        }
    }

    private var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if let latitude = place.latitude, let longitude = place.longitude {
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: place.name)
            ]
        } else {
            let query = [place.name, place.address, place.city, place.state, place.zip]
                .compactMap { $0 }
                .joined(separator: ", ")
            guard !query.isEmpty else { return nil }
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
        }
        return components?.url
    }
}

private struct DetailHero: View {
    let assetName: String?
    let symbol: String
    let eyebrow: String
    let title: String
    let subtitle: String?
    let usesFullBleedArtwork: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PathlyDashboardTheme.elevatedSurface)

                if let assetName {
                    if usesFullBleedArtwork {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    }
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.accent)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PathlyDashboardTheme.border, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PathlyDashboardTheme.softAccent)

                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .pathlyDashboardCard()
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathlyDashboardCard(cornerRadius: 20)
    }
}

private struct DetailFact: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
                Spacer(minLength: 16)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct DetailTagGroup: View {
    let title: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.secondaryText)

            FlowLayout(spacing: 7) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(PathlyDashboardTheme.accent.opacity(0.09), in: Capsule())
                }
            }
        }
        .padding(.top, 2)
    }
}

private struct DetailLink: View {
    let title: String
    let url: URL
    var emphasized = false

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(emphasized ? Color.white : PathlyDashboardTheme.softAccent)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                emphasized ? PathlyDashboardTheme.accent : PathlyDashboardTheme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Text {
    func detailBodyStyle() -> some View {
        font(.system(.body, design: .rounded))
            .foregroundStyle(PathlyDashboardTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func formatted(_ date: Date?) -> String? {
    date?.formatted(date: .long, time: .omitted)
}

private func optionalBoolean(_ value: Bool?) -> String? {
    value.map { $0 ? "Yes" : "No" }
}

private func rangeLabel(minimum: Int?, maximum: Int?, prefix: String) -> String? {
    switch (minimum, maximum) {
    case let (minimum?, maximum?) where minimum == maximum:
        "\(prefix)\(minimum)"
    case let (minimum?, maximum?):
        "\(prefix)\(minimum)–\(maximum)"
    case let (minimum?, nil):
        "\(prefix)\(minimum)+"
    case let (nil, maximum?):
        "Up to \(prefix.lowercased())\(maximum)"
    default:
        nil
    }
}

extension PlaceType {
    var categoryAssetName: String {
        switch self {
        case .library: "PlaceLibrary"
        case .makerspace: "PlaceMakerspace"
        case .fabLab: "PlaceFabLab"
        case .hackerspace: "PlaceHackerspace"
        case .innovationLab: "PlaceInnovationLab"
        case .museum: "PlaceMuseum"
        case .roboticsClub: "PlaceRoboticsClub"
        case .scienceCenter, .observatory: "PlaceScienceCenter"
        case .university: "PlaceUniversity"
        case .communityCenter, .youthCenter: "PlaceYouthCenter"
        }
    }

    fileprivate var detailSymbol: String {
        switch self {
        case .library: "books.vertical.fill"
        case .makerspace, .fabLab, .hackerspace, .innovationLab: "wrench.and.screwdriver.fill"
        case .museum, .scienceCenter: "building.columns.fill"
        case .university: "graduationcap.fill"
        case .roboticsClub: "gearshape.2.fill"
        case .communityCenter, .youthCenter: "person.3.fill"
        case .observatory: "moon.stars.fill"
        }
    }
}

private extension OpportunityCategory {
    var detailSymbol: String {
        switch self {
        case .competition: "trophy.fill"
        case .hackathon: "chevron.left.forwardslash.chevron.right"
        case .research: "flask.fill"
        case .internship: "briefcase.fill"
        case .scholarship, .grant: "dollarsign.circle.fill"
        case .program, .camp: "sparkles"
        case .workshop: "hammer.fill"
        case .event: "calendar"
        case .volunteering: "heart.fill"
        case .leadership: "person.3.fill"
        case .club: "person.2.fill"
        case .fellowship: "medal.fill"
        }
    }
}

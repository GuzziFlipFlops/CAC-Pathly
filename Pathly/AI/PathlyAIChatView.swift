import Combine
import SwiftUI

private enum PathlyAIMessageRole {
    case user
    case assistant
}

private struct PathlyAIChatMessage: Identifiable {
    let id = UUID()
    let role: PathlyAIMessageRole
    let text: String
    var opportunityIDs: [String] = []
    var placeIDs: [String] = []
    var usedLanguageModel = false
    var quickReplies: [String] = []
    var sources: String?
}

@MainActor
private final class PathlyAIChatViewModel: ObservableObject {
    @Published var messages: [PathlyAIChatMessage] = [
        PathlyAIChatMessage(
            role: .assistant,
            text: "Hi! What do you want to work on this year?"
        )
    ]
    @Published var draft = ""
    @Published var isResponding = false
    @Published private(set) var isTyping = false
    /// Status lines shown while a reply is prepared; the last one is in progress.
    @Published var statusLines: [String] = []
    @Published var availability: PathlyAIAvailability = .unavailable("Checking Apple Intelligence availability…")

    private var service: PathlyAssistantService?
    private var configurationSignature = ""

    func configure(
        dataStore: DataStore,
        profileStore: OnboardingStore,
        savedItems: SavedItemsStore,
        feedbackStore: RecommendationFeedbackStore,
        discoveryStore: PathlyDiscoveryStore
    ) {
        let signature = [
            String(dataStore.opportunities.count),
            String(dataStore.places.count),
            String(dataStore.organizations.count)
        ].joined(separator: "|")
        guard signature != configurationSignature else { return }

        let service = PathlyAssistantService(
            repository: dataStore,
            profileStore: profileStore,
            savedItems: savedItems,
            feedbackStore: feedbackStore,
            discoveryStore: discoveryStore
        )
        self.service = service
        availability = service.availability
        configurationSignature = signature
    }

    /// Types `text` into the composer at a natural pace, then sends it, so demo recordings show real typing.
    func typeAndSend(_ text: String) async {
        guard !isResponding, !isTyping else { return }
        isTyping = true
        draft = ""
        for character in text {
            draft.append(character)
            try? await Task.sleep(for: .milliseconds(character == " " ? 75 : 48))
        }
        try? await Task.sleep(for: .milliseconds(450))
        isTyping = false
        await send()
    }

    func send(_ suppliedText: String? = nil) async {
        let text = (suppliedText ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding, !isTyping, let service else { return }

        draft = ""
        messages.append(PathlyAIChatMessage(role: .user, text: text))
        isResponding = true
        defer {
            isResponding = false
            statusLines = []
        }

        if let scripted = service.scriptedReply(to: text) {
            for status in scripted.statuses {
                statusLines.append(status)
                try? await Task.sleep(for: .milliseconds(850))
            }
            messages.append(
                PathlyAIChatMessage(
                    role: .assistant,
                    text: scripted.text,
                    opportunityIDs: scripted.opportunityIDs,
                    quickReplies: scripted.quickReplies,
                    sources: scripted.sources
                )
            )
            return
        }

        statusLines = ["Searching Pathly's database…"]
        let response = await service.respond(to: text)
        messages.append(
            PathlyAIChatMessage(
                role: .assistant,
                text: response.text,
                opportunityIDs: response.opportunityIDs,
                placeIDs: response.placeIDs,
                usedLanguageModel: response.usedLanguageModel
            )
        )
    }
}

struct PathlyAIChatView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var profileStore: OnboardingStore
    @EnvironmentObject private var savedItems: SavedItemsStore
    @EnvironmentObject private var feedbackStore: RecommendationFeedbackStore
    @EnvironmentObject private var discoveryStore: PathlyDiscoveryStore

    @StateObject private var viewModel = PathlyAIChatViewModel()
    @FocusState private var isInputFocused: Bool

    #if DEBUG
    /// Launch-time test prompts run once per launch, not every time the chat opens.
    private static var hasRunLaunchPrompts = false
    #endif

    private let suggestions = [
        "Find a robotics competition I can enter this fall.",
        "What can I do near me?",
        "Show me scholarships I qualify for."
    ]

    private var organizationsByID: [String: Organization] {
        Dictionary(uniqueKeysWithValues: dataStore.organizations.map { ($0.id, $0) })
    }

    var body: some View {
        ZStack {
            PathlyDashboardBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            messageView(message)
                                .id(message.id)
                        }

                        if viewModel.messages.count == 1 {
                            suggestionGrid
                        }

                        if viewModel.isResponding {
                            thinkingIndicator
                                .id("pathly-ai-thinking")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard let last = viewModel.messages.last else { return }
                    // Land on the start of a reply so its text is read before its cards.
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: last.role == .assistant ? .top : .bottom)
                    }
                }
                .onChange(of: viewModel.statusLines.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("pathly-ai-thinking", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Ask Pathly")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
        .onAppear(perform: handleAppear)
        .onChange(of: profileStore.profile) { _, _ in configureService() }
        .onChange(of: savedItems.itemIDs) { _, _ in configureService() }
        .onChange(of: feedbackStore.snapshot) { _, _ in configureService() }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PathlyDashboardTheme.primaryText)

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    submit(suggestion)
                    PathlyHaptics.selection()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(PathlyDashboardTheme.accent)
                        Text(suggestion)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(PathlyDashboardTheme.primaryText)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PathlyDashboardTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(PathlyDashboardTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isResponding)
            }
        }
    }

    @ViewBuilder
    private func messageView(_ message: PathlyAIChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 9) {
                if message.role == .user { Spacer(minLength: 48) }

                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(PathlyDashboardTheme.accent, in: Circle())
                        .accessibilityHidden(true)
                }

                Text(Self.formatted(message.text))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(message.role == .user ? Color.white : PathlyDashboardTheme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        message.role == .user ? PathlyDashboardTheme.accent : PathlyDashboardTheme.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        if message.role == .assistant {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PathlyDashboardTheme.border, lineWidth: 1)
                        }
                    }

                if message.role == .assistant { Spacer(minLength: 20) }
            }

            if message.role == .assistant {
                ForEach(message.opportunityIDs, id: \.self) { id in
                    if let opportunity = dataStore.opportunities.first(where: { $0.id == id }),
                       let recommendation = RecommendationEngine().recommendation(
                        for: opportunity,
                        profile: profileStore.profile,
                        savedIDs: Set(savedItems.itemIDs),
                        feedback: feedbackStore.snapshot
                       ) {
                        RecommendationOpportunityCard(
                            recommendation: recommendation,
                            organization: opportunity.organizationID.flatMap { organizationsByID[$0] },
                            showsFeedback: false
                        )
                    }
                }

                ForEach(message.placeIDs, id: \.self) { id in
                    if let place = dataStore.places.first(where: { $0.id == id }) {
                        ExploreResultLink(
                            result: .place(
                                place,
                                place.organizationID.flatMap { organizationsByID[$0] }
                            ),
                            contextBadges: ["Pathly AI result"]
                        )
                    }
                }

                if let sources = message.sources {
                    Label("Sources: " + sources, systemImage: "globe")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .padding(.leading, 39)
                }

                if message.usedLanguageModel {
                    Label("Explained on device", systemImage: "iphone.gen3")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .padding(.leading, 39)
                }

                if message.id == viewModel.messages.last?.id, !message.quickReplies.isEmpty, !viewModel.isResponding, !viewModel.isTyping {
                    quickReplies(message.quickReplies)
                }
            }
        }
    }

    private var thinkingIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(viewModel.statusLines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 9) {
                    if index < viewModel.statusLines.count - 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.36))
                    } else {
                        ProgressView().controlSize(.small).tint(PathlyDashboardTheme.accent)
                    }
                    Text(line)
                        .foregroundStyle(
                            index < viewModel.statusLines.count - 1
                                ? PathlyDashboardTheme.secondaryText.opacity(0.8)
                                : PathlyDashboardTheme.secondaryText
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .padding(.leading, 40)
        .animation(.easeOut(duration: 0.2), value: viewModel.statusLines)
        .accessibilityElement(children: .combine)
    }

    private func quickReplies(_ replies: [String]) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(replies, id: \.self) { reply in
                Button {
                    submit(reply)
                    PathlyHaptics.selection()
                } label: {
                    Text(reply)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(PathlyDashboardTheme.accent.opacity(0.09), in: Capsule())
                        .overlay { Capsule().stroke(PathlyDashboardTheme.accent.opacity(0.35), lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// Renders **bold** in assistant replies while keeping line breaks.
    private static func formatted(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about opportunities or places", text: $viewModel.draft, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit(sendDraft)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(PathlyDashboardTheme.surface, in: RoundedRectangle(cornerRadius: 17))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(PathlyDashboardTheme.border, lineWidth: 1)
                }

            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(PathlyDashboardTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isResponding || viewModel.isTyping)
            .opacity(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func configureService() {
        viewModel.configure(
            dataStore: dataStore,
            profileStore: profileStore,
            savedItems: savedItems,
            feedbackStore: feedbackStore,
            discoveryStore: discoveryStore
        )
    }

    /// Sends a suggestion or quick reply. In the guided demo it is typed out first, like a person would.
    private func submit(_ text: String) {
        #if DEBUG
        if PathlyDemoScript.isEnabled {
            Task { await viewModel.typeAndSend(text) }
            return
        }
        #endif
        Task { await viewModel.send(text) }
    }

    private func handleAppear() {
        configureService()
        #if DEBUG
        guard !Self.hasRunLaunchPrompts else { return }
        let environment = ProcessInfo.processInfo.environment
        // Recording hook: types one prompt into the composer after the chat opens.
        if let typed = environment["PATHLY_DEMO_TYPE_PROMPT"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !typed.isEmpty {
            Self.hasRunLaunchPrompts = true
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                await viewModel.typeAndSend(typed)
            }
            return
        }
        let prompts: [String]
        if let sequence = environment["PATHLY_AI_PROMPTS"] {
            prompts = sequence
                .components(separatedBy: "|||")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else if let prompt = environment["PATHLY_AI_PROMPT"] {
            prompts = [prompt.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
        } else {
            prompts = []
        }
        if !prompts.isEmpty {
            Self.hasRunLaunchPrompts = true
            Task {
                for prompt in prompts {
                    await viewModel.send(prompt)
                }
            }
        }
        #endif
    }

    private func sendDraft() {
        guard !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isInputFocused = false
        Task { await viewModel.send() }
    }
}

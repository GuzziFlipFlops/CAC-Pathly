import Foundation

/// A curated, versioned roadmap for one canonical opportunity.
/// Roadmaps are planning aids written from official sources; they are not official rules.
/// They live in code, outside the catalog schema, and are keyed by opportunity ID.
struct RoadmapTemplate: Identifiable {
    let id: String
    let version: Int
    let opportunityID: String
    let title: String
    let summary: String
    let checkedDate: String
    let sources: [RoadmapLink]
    /// Short status lines shown while the roadmap is being built.
    let buildingStatuses: [String]
    let stages: [RoadmapStage]

    var stepIDs: [String] { stages.flatMap { $0.steps.map(\.id) } }

    static func template(for opportunityID: String) -> RoadmapTemplate? {
        all.first { $0.opportunityID == opportunityID }
    }

    static func template(id: String) -> RoadmapTemplate? {
        all.first { $0.id == id }
    }

    static let all: [RoadmapTemplate] = [.isef, .conrad]
}

struct RoadmapStage: Identifiable {
    let id: String
    let kicker: String
    let title: String
    let date: Date?
    let dateLabel: String
    /// Canonical record for this stage, when the stage is its own event.
    let opportunityID: String?
    let symbol: String
    let outcome: String
    let steps: [RoadmapStep]
    /// What finishing this stage leads to.
    let gate: String?
    let link: RoadmapLink?
}

struct RoadmapStep: Identifiable {
    let id: String
    let title: String
    var detail: String? = nil
    var help: RoadmapHelp? = nil
}

/// Predefined guidance shown when the student asks Pathly about a step.
struct RoadmapHelp {
    let prompt: String
    var statuses: [String] = ["Reading your roadmap…", "Checking Pathly's guide…"]
    let tips: [String]
    var footnote: String? = nil
}

struct RoadmapLink: Hashable {
    let title: String
    let url: URL
}

private func day(_ year: Int, _ month: Int, _ day: Int) -> Date? {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 12))
}

private func link(_ title: String, _ string: String) -> RoadmapLink {
    RoadmapLink(title: title, url: URL(string: string)!)
}

extension RoadmapTemplate {
    static let isef = RoadmapTemplate(
        id: "roadmap.isef.delaware",
        version: 1,
        opportunityID: "opp_000094",
        title: "Road to Regeneron ISEF",
        summary: "You can't apply to ISEF directly. From Delaware, you qualify through your county fair, then the Delaware Valley Science Fairs.",
        checkedDate: "Oct 24, 2026",
        sources: [
            link("dvsf.org", "https://www.dvsf.org/regional-fairs"),
            link("societyforscience.org", "https://www.societyforscience.org/isef/")
        ],
        buildingStatuses: [
            "Finding fairs that feed ISEF near you…",
            "Adding dates and deadlines…",
            "Breaking each stage into steps…"
        ],
        stages: [
            RoadmapStage(
                id: "isef.county",
                kicker: "Stage 1 · County fair",
                title: "New Castle County Science Fair",
                date: day(2027, 3, 9),
                dateLabel: "Mar 9, 2027 · Delaware Tech",
                opportunityID: "opp_000387",
                symbol: "flask.fill",
                outcome: "Finish a real research project and present it to judges.",
                steps: [
                    RoadmapStep(
                        id: "isef.county.question",
                        title: "Pick a research question you can test",
                        detail: "One question, one thing you can measure.",
                        help: RoadmapHelp(
                            prompt: "Help me find an AI research question",
                            statuses: ["Reading your interests…", "Checking Pathly's guide…"],
                            tips: [
                                "Start from a problem you've actually seen. Example: can a small image model spot plant disease from phone photos?",
                                "Make it testable: compare two approaches and measure accuracy, speed, or cost.",
                                "AI projects usually fit ISEF's Robotics & Intelligent Machines or Systems Software categories."
                            ]
                        )
                    ),
                    RoadmapStep(
                        id: "isef.county.sponsor",
                        title: "Ask a teacher to be your adult sponsor",
                        detail: "County fair entries go through your school.",
                        help: RoadmapHelp(
                            prompt: "How do I ask a teacher to sponsor me?",
                            tips: [
                                "Ask your science or CS teacher in person and bring a one-paragraph idea.",
                                "Want a mentor too? Email a University of Delaware lab that works on your topic.",
                                "A short, specific ask gets more replies than a general one."
                            ]
                        )
                    ),
                    RoadmapStep(
                        id: "isef.county.forms",
                        title: "Write your research plan and ISEF forms before you start",
                        detail: "Projects with people, animals, or hazardous materials need approval first.",
                        help: RoadmapHelp(
                            prompt: "Which forms do I need?",
                            tips: [
                                "Write a research plan: question, procedure, risks, and how you'll analyze data.",
                                "Complete Forms 1, 1A, and 1B with your sponsor.",
                                "Surveys and user testing count as human participants. Get approval before collecting any data."
                            ],
                            footnote: "Confirm with the ISEF Rules Wizard on societyforscience.org."
                        )
                    ),
                    RoadmapStep(id: "isef.county.research", title: "Run your experiments and keep a project notebook"),
                    RoadmapStep(id: "isef.county.board", title: "Write a 250-word abstract and build your board"),
                    RoadmapStep(id: "isef.county.present", title: "Present to judges on Mar 9")
                ],
                gate: "Selected winners are invited to the Delaware Valley Science Fairs.",
                link: link("Fair page", "https://www.dtcc.edu/about/news/events/science-fair")
            ),
            RoadmapStage(
                id: "isef.dvsf",
                kicker: "Stage 2 · Regional fair",
                title: "Delaware Valley Science Fairs",
                date: day(2027, 4, 7),
                dateLabel: "Apr 7, 2027 · Greater Philadelphia",
                opportunityID: "opp_000031",
                symbol: "medal.fill",
                outcome: "Compete with about 1,000 students for roughly 12 ISEF spots.",
                steps: [
                    RoadmapStep(id: "isef.dvsf.invite", title: "Confirm your DVSF invitation"),
                    RoadmapStep(
                        id: "isef.dvsf.register",
                        title: "Register on DVSF's STEM Wizard with your teacher",
                        detail: "Use a personal or parent email. School email often blocks outside messages."
                    ),
                    RoadmapStep(id: "isef.dvsf.preview", title: "Upload your Project Preview Document"),
                    RoadmapStep(
                        id: "isef.dvsf.improve",
                        title: "Improve your project from county judges' feedback",
                        help: RoadmapHelp(
                            prompt: "How do I use the judges' feedback?",
                            tips: [
                                "Write down every question judges asked. Those are your weak spots.",
                                "If your data was thin, add one more trial or comparison.",
                                "Rewrite your abstract around what you actually found."
                            ]
                        )
                    ),
                    RoadmapStep(id: "isef.dvsf.pitch", title: "Practice a 3-minute pitch and judge Q&A")
                ],
                gate: "DVSF sends about 12 finalists to ISEF each year.",
                link: link("DVSF student info", "https://www.dvsf.org/students")
            ),
            RoadmapStage(
                id: "isef.finals",
                kicker: "Stage 3 · International",
                title: "Regeneron ISEF 2027",
                date: day(2027, 5, 8),
                dateLabel: "May 8–14, 2027 · Los Angeles",
                opportunityID: "opp_000094",
                symbol: "globe.americas.fill",
                outcome: "Present your project to Grand Award judges with finalists from around the world.",
                steps: [
                    RoadmapStep(id: "isef.finals.paperwork", title: "Complete finalist paperwork with your fair director"),
                    RoadmapStep(id: "isef.finals.travel", title: "Plan travel to Los Angeles with your fair"),
                    RoadmapStep(id: "isef.finals.display", title: "Check your board against ISEF display rules"),
                    RoadmapStep(id: "isef.finals.judging", title: "Rehearse for Grand Award judging")
                ],
                gate: nil,
                link: link("ISEF official site", "https://www.societyforscience.org/isef/")
            )
        ]
    )

    static let conrad = RoadmapTemplate(
        id: "roadmap.conrad.2026",
        version: 1,
        opportunityID: "opp_000099",
        title: "Conrad Challenge 2026–27",
        summary: "Three phases. Phase 1 is virtual and free, and it closes Oct 29.",
        checkedDate: "Oct 24, 2026",
        sources: [link("conrad.spacecenter.org", "https://conrad.spacecenter.org/the-challenge/activation-stage/")],
        buildingStatuses: [
            "Reading Conrad's 2026–27 phases…",
            "Adding the Oct 29 deadline…",
            "Breaking each phase into steps…"
        ],
        stages: [
            RoadmapStage(
                id: "conrad.activation",
                kicker: "Phase 1 · Activation",
                title: "Build your team and Lean Canvas",
                date: day(2026, 10, 29),
                dateLabel: "Due Oct 29, 2026 · Virtual",
                opportunityID: nil,
                symbol: "person.3.fill",
                outcome: "Form a team and turn a real problem into a Lean Canvas.",
                steps: [
                    RoadmapStep(
                        id: "conrad.activation.team",
                        title: "Find 1–4 teammates",
                        detail: "Teams are 2–5 students aged 13–18.",
                        help: RoadmapHelp(
                            prompt: "Help me find teammates",
                            tips: [
                                "Ask friends from clubs that match your idea: robotics, science olympiad, or business.",
                                "Teammates can come from other schools, or even other states.",
                                "Mix skills: someone to build, someone to research, someone to present."
                            ]
                        )
                    ),
                    RoadmapStep(
                        id: "conrad.activation.coach",
                        title: "Ask an adult to be your coach",
                        detail: "A teacher, parent, or mentor over 18."
                    ),
                    RoadmapStep(
                        id: "conrad.activation.problem",
                        title: "Choose a problem and a category",
                        help: RoadmapHelp(
                            prompt: "Help me choose a problem",
                            tips: [
                                "List three problems you noticed at school or home this month.",
                                "Keep the one you can explain in a single sentence.",
                                "Match it to one of Conrad's challenge categories on the official site."
                            ]
                        )
                    ),
                    RoadmapStep(
                        id: "conrad.activation.canvas",
                        title: "Write your Lean Canvas",
                        detail: "12 questions, about 40 words each.",
                        help: RoadmapHelp(
                            prompt: "How do I write a good Lean Canvas?",
                            tips: [
                                "Lead with the problem and exactly who has it.",
                                "One real number beats three adjectives.",
                                "Read each answer aloud. If it runs past 40 words, cut it."
                            ]
                        )
                    ),
                    RoadmapStep(id: "conrad.activation.submit", title: "Register and submit in the Conrad Portal")
                ],
                gate: "Next comes the Innovation Stage. The official site explains who advances.",
                link: link("Conrad Portal", "https://conradchallenge.awardsplatform.com/")
            ),
            RoadmapStage(
                id: "conrad.innovation",
                kicker: "Phase 2 · Innovation",
                title: "Develop and test your idea",
                date: nil,
                dateLabel: "Dates on the official site",
                opportunityID: nil,
                symbol: "lightbulb.fill",
                outcome: "Show that your idea works for the people who have the problem.",
                steps: [
                    RoadmapStep(id: "conrad.innovation.rules", title: "Read the Innovation Stage requirements"),
                    RoadmapStep(id: "conrad.innovation.interviews", title: "Interview five people who have the problem"),
                    RoadmapStep(id: "conrad.innovation.prototype", title: "Build a rough prototype"),
                    RoadmapStep(id: "conrad.innovation.submit", title: "Submit your Innovation Stage entry")
                ],
                gate: "Top teams are invited to the Innovation Summit.",
                link: link("Official Conrad site", "https://conrad.spacecenter.org/")
            ),
            RoadmapStage(
                id: "conrad.summit",
                kicker: "Phase 3 · Summit",
                title: "Innovation Summit",
                date: nil,
                dateLabel: "Finalists only",
                opportunityID: nil,
                symbol: "star.fill",
                outcome: "Pitch your innovation to judges as a finalist team.",
                steps: [
                    RoadmapStep(id: "conrad.summit.finalist", title: "Check whether your team is a finalist"),
                    RoadmapStep(id: "conrad.summit.pitch", title: "Rehearse your pitch with your coach"),
                    RoadmapStep(id: "conrad.summit.travel", title: "Plan the trip with your coach")
                ],
                gate: nil,
                link: link("Official Conrad site", "https://conrad.spacecenter.org/")
            )
        ]
    )
}

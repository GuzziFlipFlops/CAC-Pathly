import EventKit
import Foundation

@MainActor
final class CalendarService {
    private let eventStore = EKEventStore()

    func addDeadline(for opportunity: Opportunity) async throws {
        guard let deadline = opportunity.deadline else {
            throw CalendarServiceError.missingDeadline
        }

        let granted = try await eventStore.requestWriteOnlyAccessToEvents()
        guard granted else {
            throw CalendarServiceError.accessDenied
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarServiceError.noWritableCalendar
        }

        var sourceCalendar = Calendar(identifier: .gregorian)
        sourceCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateComponents = sourceCalendar.dateComponents([.year, .month, .day], from: deadline)

        let userCalendar = Calendar.autoupdatingCurrent
        guard let localDeadline = userCalendar.date(from: dateComponents) else {
            throw CalendarServiceError.invalidDeadline
        }
        let start = userCalendar.startOfDay(for: localDeadline)
        guard let end = userCalendar.date(byAdding: .day, value: 1, to: start) else {
            throw CalendarServiceError.invalidDeadline
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "Deadline: \(opportunity.name)"
        event.startDate = start
        event.endDate = end
        event.isAllDay = true
        event.calendar = calendar
        event.url = opportunity.applicationURL ?? opportunity.officialURL
        event.notes = [
            opportunity.descriptionShort,
            opportunity.eligibilityNotes
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
        event.addAlarm(EKAlarm(relativeOffset: -86_400))

        try eventStore.save(event, span: .thisEvent, commit: true)
    }
}

enum CalendarServiceError: LocalizedError {
    case missingDeadline
    case accessDenied
    case noWritableCalendar
    case invalidDeadline

    var errorDescription: String? {
        switch self {
        case .missingDeadline:
            "This opportunity does not have a deadline to add."
        case .accessDenied:
            "Pathly does not have permission to add events. You can allow Calendar access in Settings."
        case .noWritableCalendar:
            "No writable calendar is available on this device."
        case .invalidDeadline:
            "Pathly could not create a calendar date for this deadline."
        }
    }
}

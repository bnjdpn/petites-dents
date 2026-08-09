import Foundation
import SwiftData

@Model
final class ChildProfile {
    static let primaryChildID = "primary"

    @Attribute(.unique) var childID: String
    var name: String = ""
    var birthDate: Date?
    var dateStorageVersion: Int = 0

    init(
        childID: String = ChildProfile.primaryChildID,
        name: String = "",
        birthDate: Date? = nil,
        dateStorageVersion: Int = 1,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.childID = childID
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.birthDate = birthDate.map { CivilDate.normalized($0, sourceCalendar: calendar) }
        self.dateStorageVersion = dateStorageVersion
    }

    func setName(_ name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setBirthDate(_ date: Date?, calendar: Calendar = .autoupdatingCurrent) {
        birthDate = date.map { CivilDate.normalized($0, sourceCalendar: calendar) }
    }
}

enum ChildProfileError: LocalizedError, Equatable {
    case nameRequired
    case profileNotFound
    case cannotDeleteLastProfile
    case birthDateAfterRecordedEvent
    case eventBeforeBirthDate

    var errorDescription: String? {
        switch self {
        case .nameRequired:
            String(localized: "profile.name_required")
        case .profileNotFound:
            String(localized: "profile.not_found")
        case .cannotDeleteLastProfile:
            String(localized: "profile.cannot_delete_last")
        case .birthDateAfterRecordedEvent:
            String(localized: "birth_date_after_recorded_event")
        case .eventBeforeBirthDate:
            String(localized: "event_before_birth_date")
        }
    }
}

import Foundation
import SwiftData

@Model
final class ChildProfile {
    static let primaryChildID = "primary"

    @Attribute(.unique) var childID: String
    var birthDate: Date?
    var dateStorageVersion: Int = 0

    init(
        childID: String = ChildProfile.primaryChildID,
        birthDate: Date? = nil,
        dateStorageVersion: Int = 1,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.childID = childID
        self.birthDate = birthDate.map { CivilDate.normalized($0, sourceCalendar: calendar) }
        self.dateStorageVersion = dateStorageVersion
    }

    func setBirthDate(_ date: Date?, calendar: Calendar = .autoupdatingCurrent) {
        birthDate = date.map { CivilDate.normalized($0, sourceCalendar: calendar) }
    }
}

enum ChildProfileError: LocalizedError {
    case birthDateAfterRecordedEvent
    case eventBeforeBirthDate

    var errorDescription: String? {
        switch self {
        case .birthDateAfterRecordedEvent:
            String(localized: "birth_date_after_recorded_event")
        case .eventBeforeBirthDate:
            String(localized: "event_before_birth_date")
        }
    }
}

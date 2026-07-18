import Foundation
import SwiftData

@Model
final class ToothRecord {
    static let primaryChildID = "primary"

    @Attribute(.unique) var recordKey: String
    var childID: String
    var toothID: String
    var teethingDate: Date?
    var eruptedDate: Date?
    var note: String

    init(
        childID: String = ToothRecord.primaryChildID,
        toothID: String,
        teethingDate: Date? = nil,
        eruptedDate: Date? = nil,
        note: String = ""
    ) {
        self.recordKey = "\(childID):\(toothID)"
        self.childID = childID
        self.toothID = toothID
        self.teethingDate = teethingDate
        self.eruptedDate = eruptedDate
        self.note = note
    }

    var status: ToothStatus {
        if eruptedDate != nil { return .erupted }
        if teethingDate != nil { return .teething }
        return .ghost
    }

    func markTeething(on date: Date, note: String, calendar: Calendar = .current) {
        teethingDate = calendar.startOfDay(for: date)
        eruptedDate = nil
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markErupted(on date: Date, note: String, calendar: Calendar = .current) throws {
        let normalized = calendar.startOfDay(for: date)
        if let teethingDate, normalized < calendar.startOfDay(for: teethingDate) {
            throw ToothRecordError.eruptionBeforeTeething
        }
        eruptedDate = normalized
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ToothRecordError: LocalizedError, Equatable {
    case eruptionBeforeTeething

    var errorDescription: String? {
        NSLocalizedString("editor.invalid_date_order", comment: "Invalid tooth date order")
    }
}

struct ToothSnapshot: Identifiable {
    let definition: ToothDefinition
    let record: ToothRecord?

    var id: String { definition.id }
    var status: ToothStatus { record?.status ?? .ghost }
}

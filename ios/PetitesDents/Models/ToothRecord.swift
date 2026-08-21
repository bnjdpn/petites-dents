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
    /// Day the baby tooth fell out. Only ever set on primary teeth.
    var sheddingDate: Date?
    /// Identifiers of the photos stored for this tooth by `ToothPhotoStore`.
    var photoIDs: [String] = []
    var note: String

    init(
        childID: String = ToothRecord.primaryChildID,
        toothID: String,
        teethingDate: Date? = nil,
        eruptedDate: Date? = nil,
        sheddingDate: Date? = nil,
        photoIDs: [String] = [],
        note: String = "",
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.recordKey = "\(childID):\(toothID)"
        self.childID = childID
        self.toothID = toothID
        self.teethingDate = teethingDate.map { CivilDate.normalized($0, sourceCalendar: calendar) }
        self.eruptedDate = eruptedDate.map { CivilDate.normalized($0, sourceCalendar: calendar) }
        self.sheddingDate = sheddingDate.map { CivilDate.normalized($0, sourceCalendar: calendar) }
        self.photoIDs = photoIDs
        self.note = note
    }

    var status: ToothStatus {
        if sheddingDate != nil { return .shed }
        if eruptedDate != nil { return .erupted }
        if teethingDate != nil { return .teething }
        return .ghost
    }

    func markTeething(on date: Date, note: String, calendar: Calendar = .autoupdatingCurrent) {
        teethingDate = CivilDate.normalized(date, sourceCalendar: calendar)
        eruptedDate = nil
        sheddingDate = nil
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markErupted(on date: Date, note: String, calendar: Calendar = .autoupdatingCurrent) throws {
        let normalized = CivilDate.normalized(date, sourceCalendar: calendar)
        if let teethingDate, normalized < teethingDate {
            throw ToothRecordError.eruptionBeforeTeething
        }
        if let sheddingDate, normalized > sheddingDate {
            throw ToothRecordError.sheddingBeforeEruption
        }
        eruptedDate = normalized
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markShed(on date: Date, note: String, calendar: Calendar = .autoupdatingCurrent) throws {
        let normalized = CivilDate.normalized(date, sourceCalendar: calendar)
        if let eruptedDate, normalized < eruptedDate {
            throw ToothRecordError.sheddingBeforeEruption
        }
        sheddingDate = normalized
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ToothRecordError: LocalizedError, Equatable {
    case eruptionBeforeTeething
    case sheddingBeforeEruption

    var errorDescription: String? {
        switch self {
        case .eruptionBeforeTeething:
            NSLocalizedString("editor.invalid_date_order", comment: "Invalid tooth date order")
        case .sheddingBeforeEruption:
            NSLocalizedString(
                "editor.invalid_shedding_order",
                comment: "Invalid shedding date order"
            )
        }
    }
}

struct ToothSnapshot: Identifiable {
    let definition: ToothDefinition
    let record: ToothRecord?

    var id: String { definition.id }
    var status: ToothStatus { record?.status ?? .ghost }
    /// True once the tooth has been recorded as through the gum, whether or
    /// not it has since fallen out.
    var hasErupted: Bool { record?.eruptedDate != nil }
    var photoIDs: [String] { record?.photoIDs ?? [] }
}

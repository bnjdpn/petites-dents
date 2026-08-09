import Foundation
import SwiftData

@MainActor
enum ScreenshotDataService {
    static func seed(in context: ModelContext) throws {
        try context.delete(model: ToothRecord.self)
        try context.delete(model: ChildProfile.self)
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!
        let birthDate = calendar.date(from: DateComponents(year: 2025, month: 10, day: 2))!
        let records = [
            ToothRecord(
                childID: ChildProfile.primaryChildID,
                toothID: "tooth-71",
                teethingDate: calendar.date(byAdding: .day, value: -12, to: base),
                eruptedDate: calendar.date(byAdding: .day, value: -8, to: base),
                note: NSLocalizedString("seed.note.71", comment: "Screenshot seed note")
            ),
            ToothRecord(
                childID: ChildProfile.primaryChildID,
                toothID: "tooth-81",
                teethingDate: calendar.date(byAdding: .day, value: -9, to: base),
                eruptedDate: calendar.date(byAdding: .day, value: -4, to: base),
                note: NSLocalizedString("seed.note.81", comment: "Screenshot seed note")
            ),
            ToothRecord(
                childID: ChildProfile.primaryChildID,
                toothID: "tooth-61",
                teethingDate: calendar.date(byAdding: .day, value: -3, to: base),
                note: NSLocalizedString("seed.note.61", comment: "Screenshot seed note")
            ),
            ToothRecord(
                childID: ChildProfile.primaryChildID,
                toothID: "tooth-51",
                teethingDate: calendar.date(byAdding: .day, value: -1, to: base),
                note: NSLocalizedString("seed.note.51", comment: "Screenshot seed note")
            ),
        ]
        records.forEach(context.insert)
        context.insert(
            ChildProfile(
                name: NSLocalizedString("seed.profile.primary", comment: "Screenshot child name"),
                birthDate: birthDate,
                calendar: calendar
            )
        )
        let secondChildID = "screenshot-secondary"
        context.insert(
            ChildProfile(
                childID: secondChildID,
                name: NSLocalizedString("seed.profile.secondary", comment: "Screenshot child name"),
                birthDate: calendar.date(from: DateComponents(year: 2025, month: 12, day: 14)),
                calendar: calendar
            )
        )
        context.insert(
            ToothRecord(
                childID: secondChildID,
                toothID: "tooth-71",
                teethingDate: calendar.date(byAdding: .day, value: -2, to: base),
                note: NSLocalizedString("seed.note.secondary", comment: "Screenshot seed note")
            )
        )
        try context.save()
    }
}

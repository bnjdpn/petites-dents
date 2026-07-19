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
                toothID: "tooth-71",
                teethingDate: calendar.date(byAdding: .day, value: -12, to: base),
                eruptedDate: calendar.date(byAdding: .day, value: -8, to: base),
                note: NSLocalizedString("seed.note.71", comment: "Screenshot seed note")
            ),
            ToothRecord(
                toothID: "tooth-81",
                teethingDate: calendar.date(byAdding: .day, value: -9, to: base),
                eruptedDate: calendar.date(byAdding: .day, value: -4, to: base),
                note: NSLocalizedString("seed.note.81", comment: "Screenshot seed note")
            ),
            ToothRecord(
                toothID: "tooth-61",
                teethingDate: calendar.date(byAdding: .day, value: -3, to: base),
                note: NSLocalizedString("seed.note.61", comment: "Screenshot seed note")
            ),
            ToothRecord(
                toothID: "tooth-51",
                teethingDate: calendar.date(byAdding: .day, value: -1, to: base),
                note: NSLocalizedString("seed.note.51", comment: "Screenshot seed note")
            ),
        ]
        records.forEach(context.insert)
        context.insert(ChildProfile(birthDate: birthDate, calendar: calendar))
        try context.save()
    }
}

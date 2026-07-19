import Foundation

enum CivilDate {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func normalized(
        _ date: Date,
        sourceCalendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        var localGregorian = Calendar(identifier: .gregorian)
        localGregorian.timeZone = sourceCalendar.timeZone
        let components = localGregorian.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components)!
    }

    static func pickerDate(
        from normalizedDate: Date,
        displayCalendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: normalizedDate)
        var localGregorian = Calendar(identifier: .gregorian)
        localGregorian.timeZone = displayCalendar.timeZone
        return localGregorian.date(from: components)!
    }

    static func normalizedLegacyLocalMidnight(_ date: Date) -> Date {
        // Versions antérieures stockaient un minuit local sans son fuseau.
        // Le milieu de la journée correspondante permet de retrouver la date
        // civile de façon déterministe, même si le téléphone a changé de fuseau.
        calendar.startOfDay(for: date.addingTimeInterval(12 * 60 * 60))
    }

    static func formatted(
        _ normalizedDate: Date,
        style: DateFormatter.Style,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: normalizedDate)
    }
}

struct CalendarAge: Equatable {
    let months: Int
    let days: Int
}

enum CalendarAgeCalculator {
    static func between(
        birthDate: Date,
        eventDate: Date,
        calendar: Calendar = CivilDate.calendar
    ) -> CalendarAge? {
        let birth = calendar.startOfDay(for: birthDate)
        let event = calendar.startOfDay(for: eventDate)
        guard event >= birth else { return nil }

        let components = calendar.dateComponents([.month, .day], from: birth, to: event)
        return CalendarAge(
            months: components.month ?? 0,
            days: components.day ?? 0
        )
    }
}

enum CalendarAgeFormatter {
    static func string(
        birthDate: Date,
        eventDate: Date,
        calendar: Calendar = CivilDate.calendar
    ) -> String? {
        guard let age = CalendarAgeCalculator.between(
            birthDate: birthDate,
            eventDate: eventDate,
            calendar: calendar
        ) else {
            return nil
        }
        return string(age: age)
    }

    static func string(age: CalendarAge) -> String {
        let monthKey = age.months == 1 ? "age.month.one" : "age.month.other"
        let dayKey = age.days == 1 ? "age.day.one" : "age.day.other"
        let months = String(
            format: NSLocalizedString(monthKey, comment: "Calendar age months"),
            age.months
        )
        let days = String(
            format: NSLocalizedString(dayKey, comment: "Calendar age days"),
            age.days
        )
        return String(
            format: NSLocalizedString("age.combined", comment: "Calendar age"),
            months,
            days
        )
    }
}

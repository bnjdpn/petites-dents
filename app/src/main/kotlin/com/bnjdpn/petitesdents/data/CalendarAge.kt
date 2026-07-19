package com.bnjdpn.petitesdents.data

import android.content.Context
import com.bnjdpn.petitesdents.R
import java.time.LocalDate
import java.time.temporal.ChronoUnit

data class CalendarAge(
    val months: Int,
    val days: Int,
)

object CalendarAgeCalculator {
    fun between(birthDate: LocalDate, eventDate: LocalDate): CalendarAge? {
        if (eventDate < birthDate) return null

        var months = (eventDate.year - birthDate.year) * 12 +
            eventDate.monthValue - birthDate.monthValue
        var monthAnniversary = birthDate.plusMonths(months.toLong())
        if (monthAnniversary > eventDate) {
            months -= 1
            monthAnniversary = birthDate.plusMonths(months.toLong())
        }

        return CalendarAge(
            months = months,
            days = ChronoUnit.DAYS.between(monthAnniversary, eventDate).toInt(),
        )
    }

    fun betweenEpochDays(birthEpochDay: Long, eventEpochDay: Long): CalendarAge? = between(
        birthDate = LocalDate.ofEpochDay(birthEpochDay),
        eventDate = LocalDate.ofEpochDay(eventEpochDay),
    )
}

fun CalendarAge.localized(context: Context): String {
    val monthText = context.resources.getQuantityString(
        R.plurals.age_months,
        months,
        months,
    )
    val dayText = context.resources.getQuantityString(
        R.plurals.age_days,
        days,
        days,
    )
    return context.getString(R.string.age_months_days, monthText, dayText)
}

fun formatCalendarAge(
    context: Context,
    birthEpochDay: Long,
    eventEpochDay: Long,
): String? = CalendarAgeCalculator.betweenEpochDays(birthEpochDay, eventEpochDay)?.localized(context)

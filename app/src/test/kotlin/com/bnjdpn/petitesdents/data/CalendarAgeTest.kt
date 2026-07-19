package com.bnjdpn.petitesdents.data

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CalendarAgeTest {
    @Test
    fun sameDayIsZeroMonthsAndZeroDays() {
        val date = LocalDate.of(2026, 7, 18)

        assertEquals(CalendarAge(0, 0), CalendarAgeCalculator.between(date, date))
    }

    @Test
    fun camillesExampleUsesFullCalendarMonths() {
        val age = CalendarAgeCalculator.between(
            birthDate = LocalDate.of(2025, 10, 2),
            eventDate = LocalDate.of(2026, 7, 18),
        )

        assertEquals(CalendarAge(9, 16), age)
    }

    @Test
    fun endOfMonthCountsTheClampedMonthAnniversary() {
        val age = CalendarAgeCalculator.between(
            birthDate = LocalDate.of(2025, 1, 31),
            eventDate = LocalDate.of(2025, 2, 28),
        )

        assertEquals(CalendarAge(1, 0), age)
    }

    @Test
    fun leapDayToFollowingFebruaryIsTwelveMonths() {
        val age = CalendarAgeCalculator.between(
            birthDate = LocalDate.of(2024, 2, 29),
            eventDate = LocalDate.of(2025, 2, 28),
        )

        assertEquals(CalendarAge(12, 0), age)
    }

    @Test
    fun eventBeforeBirthDateHasNoAge() {
        val age = CalendarAgeCalculator.between(
            birthDate = LocalDate.of(2026, 7, 19),
            eventDate = LocalDate.of(2026, 7, 18),
        )

        assertNull(age)
    }
}

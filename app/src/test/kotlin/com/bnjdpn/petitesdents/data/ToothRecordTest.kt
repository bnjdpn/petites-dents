package com.bnjdpn.petitesdents.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ToothRecordTest {
    @Test
    fun recordMovesThroughTheThreeStates() {
        val initial = ToothRecordEntity(toothId = "tooth-71")
        assertEquals(ToothStatus.GHOST, initial.status)

        val teething = initial.markTeething(epochDay = 20_000, updatedNote = "  Red cheeks  ")
        assertEquals(ToothStatus.TEETHING, teething.status)
        assertEquals("Red cheeks", teething.note)

        val erupted = teething.markErupted(epochDay = 20_003, updatedNote = teething.note)
        assertEquals(ToothStatus.ERUPTED, erupted.status)
        assertEquals(20_003L, erupted.eruptedEpochDay)
    }

    @Test
    fun eruptedCanBeRecordedWithoutAStartDate() {
        val erupted = ToothRecordEntity(toothId = "tooth-51")
            .markErupted(epochDay = 20_010, updatedNote = "Already visible")

        assertNull(erupted.teethingEpochDay)
        assertEquals(ToothStatus.ERUPTED, erupted.status)
    }

    @Test(expected = IllegalArgumentException::class)
    fun eruptionCannotPrecedeARecordedTeethingDate() {
        ToothRecordEntity(toothId = "tooth-61")
            .markTeething(epochDay = 20_010, updatedNote = "")
            .markErupted(epochDay = 20_009, updatedNote = "")
    }

    @Test
    fun markingTeethingAgainReturnsAnEruptedToothToTeething() {
        val record = ToothRecordEntity(toothId = "tooth-81")
            .markErupted(epochDay = 20_001, updatedNote = "")
            .markTeething(epochDay = 20_005, updatedNote = "Second observation")

        assertEquals(ToothStatus.TEETHING, record.status)
        assertNull(record.eruptedEpochDay)
    }
}

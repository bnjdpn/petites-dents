package com.bnjdpn.petitesdents.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ToothCatalogTest {
    @Test
    fun catalogContainsTwentyUniquePrimaryTeethInAnatomicalArches() {
        assertEquals(20, ToothCatalog.all.size)
        assertEquals(20, ToothCatalog.all.map { it.id }.toSet().size)
        assertEquals(10, ToothCatalog.upper.size)
        assertEquals(10, ToothCatalog.lower.size)
        assertEquals(listOf(65, 64, 63, 62, 61, 51, 52, 53, 54, 55), ToothCatalog.upper.map { it.fdi })
        assertEquals(listOf(75, 74, 73, 72, 71, 81, 82, 83, 84, 85), ToothCatalog.lower.map { it.fdi })
    }

    @Test
    fun appearanceRangesMatchTheSpecification() {
        val lowerCentral = ToothCatalog.all.first { it.fdi == 71 }
        val upperCentral = ToothCatalog.all.first { it.fdi == 61 }
        val secondMolar = ToothCatalog.all.first { it.fdi == 65 }

        assertEquals(6..10, lowerCentral.minMonths..lowerCentral.maxMonths)
        assertEquals(8..12, upperCentral.minMonths..upperCentral.maxMonths)
        assertEquals(25..33, secondMolar.minMonths..secondMolar.maxMonths)
        assertTrue(ToothCatalog.all.all { it.minMonths < it.maxMonths })
    }
}

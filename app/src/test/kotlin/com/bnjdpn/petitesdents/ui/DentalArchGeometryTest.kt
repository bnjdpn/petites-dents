package com.bnjdpn.petitesdents.ui

import com.bnjdpn.petitesdents.data.ToothArch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DentalArchGeometryTest {
    @Test
    fun archesContainTenMirroredPlacements() {
        val upper = DentalArchGeometry.placements(ToothArch.UPPER)
        val lower = DentalArchGeometry.placements(ToothArch.LOWER)

        assertEquals(10, upper.size)
        assertEquals(10, lower.size)
        upper.indices.forEach { index ->
            assertEquals(upper[index].xFraction, lower[index].xFraction, 0.0001f)
            assertEquals(1f, upper[index].yFraction + lower[index].yFraction, 0.0001f)
        }
    }

    @Test
    fun upperAndLowerFollowHorseshoeCurves() {
        val upper = DentalArchGeometry.placements(ToothArch.UPPER)
        val lower = DentalArchGeometry.placements(ToothArch.LOWER)

        assertTrue(upper.first().yFraction > upper[4].yFraction)
        assertEquals(upper[4].yFraction, upper[5].yFraction, 0.0001f)
        assertTrue(lower.first().yFraction < lower[4].yFraction)
        assertEquals(lower[4].yFraction, lower[5].yFraction, 0.0001f)
    }

    @Test
    fun placementsAndRotationsAreSymmetric() {
        val upper = DentalArchGeometry.placements(ToothArch.UPPER)
        val lower = DentalArchGeometry.placements(ToothArch.LOWER)

        upper.indices.forEach { index ->
            val mirroredIndex = upper.lastIndex - index
            assertEquals(1f, upper[index].xFraction + upper[mirroredIndex].xFraction, 0.0001f)
            assertEquals(upper[index].yFraction, upper[mirroredIndex].yFraction, 0.0001f)
            assertEquals(360f, upper[index].rotationDegrees + upper[mirroredIndex].rotationDegrees, 0.0001f)
            assertEquals(0f, lower[index].rotationDegrees + lower[mirroredIndex].rotationDegrees, 0.0001f)
        }
    }

    @Test
    fun heightPreservesCurveRatioAcrossPhoneAndTabletWidths() {
        assertEquals(164f, DentalArchGeometry.heightForWidth(280f), 0.0001f)
        assertEquals(182f, DentalArchGeometry.heightForWidth(350f), 0.0001f)
        assertEquals(395.2f, DentalArchGeometry.heightForWidth(760f), 0.0001f)
        assertEquals(624f, DentalArchGeometry.heightForWidth(1200f), 0.0001f)
    }

    @Test
    fun fdiOrderMatchesAnatomicalCatalogOrder() {
        assertEquals(listOf(65, 64, 63, 62, 61, 51, 52, 53, 54, 55), DentalArchGeometry.expectedFdis(ToothArch.UPPER))
        assertEquals(listOf(75, 74, 73, 72, 71, 81, 82, 83, 84, 85), DentalArchGeometry.expectedFdis(ToothArch.LOWER))
    }

    @Test
    fun outerTargetsKeepAFullTouchInsetAtTheNarrowestWidth() {
        val placements = DentalArchGeometry.placements(ToothArch.UPPER)
        assertTrue(placements.first().xFraction * 280f >= 24f)
        assertTrue((1f - placements.last().xFraction) * 280f >= 24f)
    }
}

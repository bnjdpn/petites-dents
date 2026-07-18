package com.bnjdpn.petitesdents.ui

import com.bnjdpn.petitesdents.data.ToothArch

internal data class DentalArchPlacement(
    val xFraction: Float,
    val yFraction: Float,
    val rotationDegrees: Float,
)

internal object DentalArchGeometry {
    const val GUM_OUTER_X = 0.090f
    const val GUM_OUTER_Y = 0.760f
    const val GUM_CONTROL_1_X = 0.120f
    const val GUM_SHOULDER_Y = 0.430f
    const val GUM_CONTROL_2_X = 0.280f
    const val GUM_CENTER_X = 0.500f
    const val GUM_CENTER_Y = 0.235f

    private val upperFdis = listOf(65, 64, 63, 62, 61, 51, 52, 53, 54, 55)
    private val lowerFdis = listOf(75, 74, 73, 72, 71, 81, 82, 83, 84, 85)

    private val xFractions = listOf(
        0.090f,
        0.180f,
        0.270f,
        0.360f,
        0.450f,
        0.550f,
        0.640f,
        0.730f,
        0.820f,
        0.910f,
    )

    private val upperYFractions = xFractions.map(::upperGumYFraction)

    private val tangentRotations = listOf(
        -17f,
        -14f,
        -10f,
        -6f,
        -2f,
        2f,
        6f,
        10f,
        14f,
        17f,
    )

    fun placements(arch: ToothArch): List<DentalArchPlacement> = xFractions.indices.map { index ->
        val upperY = upperYFractions[index]
        DentalArchPlacement(
            xFraction = xFractions[index],
            yFraction = if (arch == ToothArch.UPPER) upperY else 1f - upperY,
            rotationDegrees = if (arch == ToothArch.UPPER) {
                180f + tangentRotations[index]
            } else {
                -tangentRotations[index]
            },
        )
    }

    fun expectedFdis(arch: ToothArch): List<Int> = when (arch) {
        ToothArch.UPPER -> upperFdis
        ToothArch.LOWER -> lowerFdis
    }

    fun heightForWidth(widthDp: Float): Float = (widthDp * 0.52f).coerceAtLeast(164f)

    private fun upperGumYFraction(xFraction: Float): Float {
        val leftX = minOf(xFraction, 1f - xFraction)
        var low = 0f
        var high = 1f
        repeat(32) {
            val middle = (low + high) / 2f
            if (cubic(GUM_OUTER_X, GUM_CONTROL_1_X, GUM_CONTROL_2_X, GUM_CENTER_X, middle) < leftX) {
                low = middle
            } else {
                high = middle
            }
        }
        return cubic(
            GUM_OUTER_Y,
            GUM_SHOULDER_Y,
            GUM_CENTER_Y,
            GUM_CENTER_Y,
            (low + high) / 2f,
        )
    }

    private fun cubic(start: Float, control1: Float, control2: Float, end: Float, t: Float): Float {
        val inverse = 1f - t
        return inverse * inverse * inverse * start +
            3f * inverse * inverse * t * control1 +
            3f * inverse * t * t * control2 +
            t * t * t * end
    }
}

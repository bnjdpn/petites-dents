package com.bnjdpn.petitesdents.ui

import com.bnjdpn.petitesdents.data.ToothArch

internal data class DentalArchPlacement(
    val xFraction: Float,
    val yFraction: Float,
    val rotationDegrees: Float,
)

internal object DentalArchGeometry {
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

    private val upperYFractions = listOf(
        0.760f,
        0.590f,
        0.430f,
        0.310f,
        0.235f,
        0.235f,
        0.310f,
        0.430f,
        0.590f,
        0.760f,
    )

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
}

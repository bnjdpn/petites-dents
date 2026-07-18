package com.bnjdpn.petitesdents.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.bnjdpn.petitesdents.data.ToothKind

val Coral = Color(0xFFFF7468)
val CoralSoft = Color(0xFFFFD8D0)
val Apricot = Color(0xFFFFE6C7)
val Sage = Color(0xFF819B7A)
val GhostFill = Color(0xFFE4E2E0)
val Ink = Color(0xFF342C2A)
val Cream = Color(0xFFFFFAF4)

internal enum class ToothFamilyOutline(val color: Color) {
    CENTRAL_INCISOR(Color(0xFFD93F82)),
    LATERAL_INCISOR(Color(0xFF159EA6)),
    CANINE(Color(0xFF3B82F6)),
    FIRST_MOLAR(Color(0xFF075985)),
    SECOND_MOLAR(Color(0xFF353535)),
}

internal val ToothKind.familyOutline: ToothFamilyOutline
    get() = when (this) {
        ToothKind.CENTRAL_INCISOR -> ToothFamilyOutline.CENTRAL_INCISOR
        ToothKind.LATERAL_INCISOR -> ToothFamilyOutline.LATERAL_INCISOR
        ToothKind.CANINE -> ToothFamilyOutline.CANINE
        ToothKind.FIRST_MOLAR -> ToothFamilyOutline.FIRST_MOLAR
        ToothKind.SECOND_MOLAR -> ToothFamilyOutline.SECOND_MOLAR
    }

private val LightColors = lightColorScheme(
    primary = Coral,
    onPrimary = Color.White,
    primaryContainer = CoralSoft,
    onPrimaryContainer = Ink,
    secondary = Sage,
    onSecondary = Color.White,
    background = Cream,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFFFA297),
    secondary = Color(0xFFB1CDAA),
    background = Color(0xFF211B1A),
    surface = Color(0xFF2C2422),
)

@Composable
fun PetitesDentsTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}

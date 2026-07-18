package com.bnjdpn.petitesdents.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Coral = Color(0xFFFF7468)
val CoralSoft = Color(0xFFFFD8D0)
val Apricot = Color(0xFFFFE6C7)
val Sage = Color(0xFF819B7A)
val Ink = Color(0xFF342C2A)
val Cream = Color(0xFFFFFAF4)

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

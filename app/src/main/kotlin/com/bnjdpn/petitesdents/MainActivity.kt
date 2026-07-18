package com.bnjdpn.petitesdents

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.bnjdpn.petitesdents.ui.PetitesDentsRoot
import com.bnjdpn.petitesdents.ui.PetitesDentsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PetitesDentsTheme {
                PetitesDentsRoot()
            }
        }
    }
}

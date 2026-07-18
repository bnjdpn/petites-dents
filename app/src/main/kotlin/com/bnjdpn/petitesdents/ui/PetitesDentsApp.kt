package com.bnjdpn.petitesdents.ui

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.SentimentSatisfied
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bnjdpn.petitesdents.PetitesDentsApplication
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.TeethViewModel

private enum class AppTab(
    @StringRes val title: Int,
    val icon: ImageVector,
) {
    TEETH(R.string.tab_teeth, Icons.Rounded.SentimentSatisfied),
    HISTORY(R.string.tab_history, Icons.Rounded.History),
    MORE(R.string.tab_more, Icons.Rounded.MoreHoriz),
}

@Composable
fun PetitesDentsRoot() {
    val context = LocalContext.current
    val application = context.applicationContext as PetitesDentsApplication
    val factory = remember(application) { TeethViewModel.Factory(application.repository) }
    val viewModel: TeethViewModel = viewModel(factory = factory)
    val teeth by viewModel.teeth.collectAsStateWithLifecycle()

    var selectedTab by remember { mutableStateOf(AppTab.TEETH) }
    var selectedToothId by remember { mutableStateOf<String?>(null) }
    val selectedTooth = teeth.firstOrNull { it.definition.id == selectedToothId }

    Scaffold(
        bottomBar = {
            NavigationBar {
                AppTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.title)) },
                    )
                }
            }
        },
    ) { padding ->
        when (selectedTab) {
            AppTab.TEETH -> MouthScreen(
                teeth = teeth,
                onSelect = { selectedToothId = it.definition.id },
                modifier = Modifier.padding(padding),
            )

            AppTab.HISTORY -> HistoryScreen(
                teeth = teeth,
                onSelect = { selectedToothId = it.definition.id },
                modifier = Modifier.padding(padding),
            )

            AppTab.MORE -> MoreScreen(
                teeth = teeth,
                modifier = Modifier.padding(padding),
            )
        }
    }

    selectedTooth?.let { tooth ->
        ToothEditorSheet(
            snapshot = tooth,
            onDismiss = { selectedToothId = null },
            onSaveNote = { note ->
                viewModel.saveNote(tooth, note)
                selectedToothId = null
            },
            onMarkTeething = { day, note ->
                viewModel.markTeething(tooth, day, note)
                selectedToothId = null
            },
            onMarkErupted = { day, note ->
                viewModel.markErupted(tooth, day, note)
                selectedToothId = null
            },
            onReset = {
                viewModel.reset(tooth)
                selectedToothId = null
            },
        )
    }
}

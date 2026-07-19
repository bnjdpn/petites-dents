package com.bnjdpn.petitesdents.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.data.formatCalendarAge
import com.bnjdpn.petitesdents.data.ToothSnapshot
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@Composable
fun HistoryScreen(
    teeth: List<ToothSnapshot>,
    birthDateEpochDay: Long?,
    onSelect: (ToothSnapshot) -> Unit,
    modifier: Modifier = Modifier,
) {
    val history = teeth
        .filter { it.record.eruptedEpochDay != null }
        .sortedByDescending { it.record.eruptedEpochDay }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 20.dp,
            top = 18.dp,
            end = 20.dp,
            bottom = 32.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.history_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = stringResource(R.string.history_subtitle),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 6.dp, bottom = 10.dp),
            )
        }

        if (history.isEmpty()) {
            item { EmptyHistory() }
        } else {
            items(history, key = { it.definition.id }) { tooth ->
                HistoryCard(
                    tooth = tooth,
                    birthDateEpochDay = birthDateEpochDay,
                    onClick = { onSelect(tooth) },
                )
            }
        }
    }
}

@Composable
private fun EmptyHistory() {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(28.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.AutoAwesome,
                contentDescription = null,
                tint = Coral,
            )
            Text(
                text = stringResource(R.string.history_empty_title),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 12.dp),
            )
            Text(
                text = stringResource(R.string.history_empty_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 5.dp),
            )
        }
    }
}

@Composable
private fun HistoryCard(
    tooth: ToothSnapshot,
    birthDateEpochDay: Long?,
    onClick: () -> Unit,
) {
    val context = LocalContext.current
    val eruptedEpochDay = tooth.record.eruptedEpochDay
    val date = eruptedEpochDay?.let(::formatEpochDay).orEmpty()
    val age = if (birthDateEpochDay != null && eruptedEpochDay != null) {
        formatCalendarAge(context, birthDateEpochDay, eruptedEpochDay)
    } else {
        null
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(16.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.AutoAwesome,
                contentDescription = null,
                tint = Sage,
            )
            Column(modifier = Modifier.padding(start = 14.dp)) {
                Text(
                    text = tooth.definition.localizedName(context),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = age?.let {
                        stringResource(R.string.erupted_on_with_age, date, it)
                    } ?: stringResource(R.string.erupted_on, date),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (tooth.record.note.isNotBlank()) {
                    Text(
                        text = tooth.record.note,
                        style = MaterialTheme.typography.bodySmall,
                        maxLines = 2,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }
    }
}

fun formatEpochDay(epochDay: Long): String = LocalDate.ofEpochDay(epochDay)
    .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))

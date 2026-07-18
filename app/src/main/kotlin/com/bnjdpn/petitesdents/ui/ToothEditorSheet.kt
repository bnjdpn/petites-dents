package com.bnjdpn.petitesdents.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.data.ToothSnapshot
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToothEditorSheet(
    snapshot: ToothSnapshot,
    onDismiss: () -> Unit,
    onSaveNote: (String) -> Unit,
    onMarkTeething: (Long, String) -> Unit,
    onMarkErupted: (Long, String) -> Unit,
    onReset: () -> Unit,
) {
    val context = LocalContext.current
    val today = LocalDate.now().toEpochDay()
    val initialDate = snapshot.record.eruptedEpochDay
        ?: snapshot.record.teethingEpochDay
        ?: today
    var selectedEpochDay by remember(snapshot.definition.id) { mutableLongStateOf(initialDate) }
    var note by remember(snapshot.definition.id, snapshot.record.note) {
        mutableStateOf(snapshot.record.note)
    }
    var showDatePicker by remember { mutableStateOf(false) }
    var showResetConfirmation by remember { mutableStateOf(false) }
    var invalidOrder by remember { mutableStateOf(false) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .imePadding()
                .padding(start = 20.dp, end = 20.dp, bottom = 24.dp),
        ) {
            Text(
                text = snapshot.definition.localizedName(context),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = stringResource(
                    R.string.current_status,
                    stringResource(snapshot.record.status.stringResource),
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                text = stringResource(
                    R.string.typical_age,
                    snapshot.definition.minMonths,
                    snapshot.definition.maxMonths,
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp, bottom = 16.dp),
            )

            OutlinedButton(
                onClick = { showDatePicker = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("editor-date"),
            ) {
                androidx.compose.material3.Icon(Icons.Rounded.CalendarMonth, contentDescription = null)
                Text(
                    text = formatEpochDay(selectedEpochDay),
                    modifier = Modifier.padding(start = 8.dp),
                )
            }

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text(stringResource(R.string.note_label)) },
                placeholder = { Text(stringResource(R.string.note_placeholder)) },
                minLines = 3,
                maxLines = 6,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .testTag("editor-note"),
            )

            if (invalidOrder) {
                Text(
                    text = stringResource(R.string.invalid_date_order),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }

            Button(
                onClick = { onMarkTeething(selectedEpochDay, note) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .testTag("mark-teething"),
            ) {
                Text(stringResource(R.string.mark_teething))
            }

            Button(
                onClick = {
                    if (snapshot.record.teethingEpochDay != null &&
                        selectedEpochDay < snapshot.record.teethingEpochDay
                    ) {
                        invalidOrder = true
                    } else {
                        onMarkErupted(selectedEpochDay, note)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .testTag("mark-erupted"),
            ) {
                Text(stringResource(R.string.mark_erupted))
            }

            OutlinedButton(
                onClick = { onSaveNote(note) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            ) {
                Text(stringResource(R.string.save_note))
            }

            if (snapshot.record.status != com.bnjdpn.petitesdents.data.ToothStatus.GHOST ||
                snapshot.record.note.isNotBlank()
            ) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 14.dp))
                TextButton(
                    onClick = { showResetConfirmation = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = stringResource(R.string.reset_tooth),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.close))
            }
        }
    }

    if (showDatePicker) {
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = LocalDate.ofEpochDay(selectedEpochDay)
                .atStartOfDay(ZoneOffset.UTC)
                .toInstant()
                .toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    utcTimeMillis <= LocalDate.now()
                        .atStartOfDay(ZoneOffset.UTC)
                        .toInstant()
                        .toEpochMilli()
            },
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let { millis ->
                        selectedEpochDay = Instant.ofEpochMilli(millis)
                            .atZone(ZoneOffset.UTC)
                            .toLocalDate()
                            .toEpochDay()
                        invalidOrder = false
                    }
                    showDatePicker = false
                }) { Text(stringResource(android.R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text(stringResource(R.string.cancel))
                }
            },
        ) {
            DatePicker(state = pickerState)
        }
    }

    if (showResetConfirmation) {
        AlertDialog(
            onDismissRequest = { showResetConfirmation = false },
            title = { Text(stringResource(R.string.confirm_reset_title)) },
            text = { Text(stringResource(R.string.confirm_reset_body)) },
            confirmButton = {
                TextButton(onClick = onReset) {
                    Text(
                        text = stringResource(R.string.reset_tooth),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirmation = false }) {
                    Text(stringResource(R.string.cancel))
                }
            },
        )
    }
}

package com.bnjdpn.petitesdents.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.SupportAgent
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.data.ToothSnapshot
import com.bnjdpn.petitesdents.export.TeethPdfExporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun MoreScreen(teeth: List<ToothSnapshot>, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var exportFailed by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 18.dp),
    ) {
        Text(
            text = stringResource(R.string.more_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = stringResource(R.string.more_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 6.dp),
        )

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 18.dp),
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Description, contentDescription = null, tint = Coral)
                    Text(
                        text = stringResource(R.string.export_pdf),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 10.dp),
                    )
                }
                Text(
                    text = stringResource(R.string.export_pdf_detail),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
                Button(
                    onClick = {
                        exportFailed = false
                        scope.launch {
                            runCatching {
                                withContext(Dispatchers.IO) {
                                    TeethPdfExporter.create(context, teeth)
                                }
                            }.onSuccess { file ->
                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.files",
                                    file,
                                )
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "application/pdf"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                context.startActivity(
                                    Intent.createChooser(
                                        intent,
                                        context.getString(R.string.share_pdf),
                                    ),
                                )
                            }.onFailure { exportFailed = true }
                        }
                    },
                    enabled = teeth.size == 20,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp)
                        .testTag("export-pdf"),
                ) {
                    Text(stringResource(R.string.export_pdf))
                }
                if (exportFailed) {
                    Text(
                        text = stringResource(R.string.export_failed),
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }
        }

        Text(
            text = stringResource(R.string.support_title),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 24.dp, bottom = 10.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = { context.openUrl("https://bnjdpn.github.io/petites-dents/#contact") },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Rounded.SupportAgent, contentDescription = null)
                Text(stringResource(R.string.support), modifier = Modifier.padding(start = 8.dp))
            }
            OutlinedButton(
                onClick = { context.openUrl("https://bnjdpn.github.io/petites-dents/privacy.html") },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Rounded.Lock, contentDescription = null)
                Text(stringResource(R.string.privacy), modifier = Modifier.padding(start = 8.dp))
            }
        }

        Text(
            text = stringResource(R.string.medical_disclaimer),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 24.dp, bottom = 28.dp),
        )
    }
}

private fun android.content.Context.openUrl(url: String) {
    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}

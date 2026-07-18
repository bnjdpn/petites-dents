package com.bnjdpn.petitesdents.ui

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.data.ToothArch
import com.bnjdpn.petitesdents.data.ToothDefinition
import com.bnjdpn.petitesdents.data.ToothKind
import com.bnjdpn.petitesdents.data.ToothSide
import com.bnjdpn.petitesdents.data.ToothSnapshot
import com.bnjdpn.petitesdents.data.ToothStatus

@Composable
fun MouthScreen(
    teeth: List<ToothSnapshot>,
    onSelect: (ToothSnapshot) -> Unit,
    modifier: Modifier = Modifier,
) {
    val erupted = teeth.count { it.record.status == ToothStatus.ERUPTED }
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 18.dp),
    ) {
        Text(
            text = stringResource(R.string.mouth_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = stringResource(R.string.mouth_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 6.dp),
        )

        Surface(
            color = MaterialTheme.colorScheme.primaryContainer,
            shape = RoundedCornerShape(999.dp),
            modifier = Modifier.padding(top = 16.dp),
        ) {
            Text(
                text = stringResource(R.string.progress_erupted, erupted),
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            )
        }

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 18.dp),
        ) {
            Column(modifier = Modifier.padding(vertical = 18.dp)) {
                ToothArchRow(
                    title = stringResource(R.string.upper_arch),
                    teeth = teeth.filter { it.definition.arch == ToothArch.UPPER },
                    isUpper = true,
                    onSelect = onSelect,
                )

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp, vertical = 8.dp)
                        .height(42.dp)
                        .clip(RoundedCornerShape(50))
                        .background(CoralSoft.copy(alpha = 0.55f)),
                )

                ToothArchRow(
                    title = stringResource(R.string.lower_arch),
                    teeth = teeth.filter { it.definition.arch == ToothArch.LOWER },
                    isUpper = false,
                    onSelect = onSelect,
                )
                Text(
                    text = stringResource(R.string.scroll_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
                )
            }
        }

        Legend(modifier = Modifier.padding(top = 18.dp, bottom = 24.dp))
    }
}

@Composable
private fun ToothArchRow(
    title: String,
    teeth: List<ToothSnapshot>,
    isUpper: Boolean,
    onSelect: (ToothSnapshot) -> Unit,
) {
    val offsets = if (isUpper) listOf(11, 7, 4, 2, 0, 0, 2, 4, 7, 11)
    else listOf(0, 2, 4, 7, 11, 11, 7, 4, 2, 0)

    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
    )
    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp),
    ) {
        teeth.forEachIndexed { index, tooth ->
            Box(modifier = Modifier.padding(top = offsets[index].dp)) {
                ToothButton(tooth = tooth, onClick = { onSelect(tooth) })
            }
        }
    }
}

@Composable
private fun ToothButton(tooth: ToothSnapshot, onClick: () -> Unit) {
    val context = LocalContext.current
    val name = tooth.definition.localizedName(context)
    val state = stringResource(tooth.record.status.stringResource)
    val description = stringResource(
        R.string.tooth_accessibility,
        name,
        tooth.definition.fdi,
        state,
    )
    val outline = MaterialTheme.colorScheme.outline
    val fill = when (tooth.record.status) {
        ToothStatus.GHOST -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.18f)
        ToothStatus.TEETHING -> Apricot
        ToothStatus.ERUPTED -> Color(0xFFFFFEF8)
    }

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(width = 48.dp, height = 58.dp)
            .testTag("tooth-${tooth.definition.fdi}")
            .semantics(mergeDescendants = true) {
                contentDescription = description
                stateDescription = state
            }
            .clickable(onClick = onClick),
    ) {
        Canvas(modifier = Modifier.size(width = 36.dp, height = 46.dp)) {
            val path = toothPath(size)
            drawPath(path, color = fill, style = Fill)
            drawPath(
                path = path,
                color = if (tooth.record.status == ToothStatus.TEETHING) Coral else outline,
                style = Stroke(
                    width = if (tooth.record.status == ToothStatus.ERUPTED) 2.5f else 2f,
                    pathEffect = if (tooth.record.status == ToothStatus.GHOST) {
                        PathEffect.dashPathEffect(floatArrayOf(7f, 6f))
                    } else null,
                ),
            )
        }
        if (tooth.record.status == ToothStatus.ERUPTED) {
            Icon(
                imageVector = Icons.Rounded.Check,
                contentDescription = null,
                tint = Sage,
                modifier = Modifier.size(19.dp),
            )
        }
    }
}

private fun toothPath(size: Size): Path = Path().apply {
    val w = size.width
    val h = size.height
    moveTo(w * 0.50f, h * 0.08f)
    cubicTo(w * 0.28f, -h * 0.02f, w * 0.10f, h * 0.12f, w * 0.14f, h * 0.35f)
    cubicTo(w * 0.18f, h * 0.58f, w * 0.26f, h * 0.88f, w * 0.38f, h * 0.93f)
    cubicTo(w * 0.46f, h * 0.96f, w * 0.44f, h * 0.72f, w * 0.50f, h * 0.70f)
    cubicTo(w * 0.56f, h * 0.72f, w * 0.54f, h * 0.96f, w * 0.62f, h * 0.93f)
    cubicTo(w * 0.74f, h * 0.88f, w * 0.82f, h * 0.58f, w * 0.86f, h * 0.35f)
    cubicTo(w * 0.90f, h * 0.12f, w * 0.72f, -h * 0.02f, w * 0.50f, h * 0.08f)
    close()
}

@Composable
private fun Legend(modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = stringResource(R.string.legend_title),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            ToothStatus.entries.forEach { status ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(RoundedCornerShape(50))
                            .background(
                                when (status) {
                                    ToothStatus.GHOST -> MaterialTheme.colorScheme.outlineVariant
                                    ToothStatus.TEETHING -> Apricot
                                    ToothStatus.ERUPTED -> Sage
                                },
                            ),
                    )
                    Text(
                        text = stringResource(status.stringResource),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(start = 5.dp),
                    )
                }
            }
        }
    }
}

val ToothStatus.stringResource: Int
    get() = when (this) {
        ToothStatus.GHOST -> R.string.state_ghost
        ToothStatus.TEETHING -> R.string.state_teething
        ToothStatus.ERUPTED -> R.string.state_erupted
    }

fun ToothDefinition.localizedName(context: Context): String {
    val arch = context.getString(if (arch == ToothArch.UPPER) R.string.arch_upper else R.string.arch_lower)
    val side = context.getString(if (side == ToothSide.LEFT) R.string.side_left else R.string.side_right)
    val kind = context.getString(
        when (kind) {
            ToothKind.CENTRAL_INCISOR -> R.string.kind_central_incisor
            ToothKind.LATERAL_INCISOR -> R.string.kind_lateral_incisor
            ToothKind.CANINE -> R.string.kind_canine
            ToothKind.FIRST_MOLAR -> R.string.kind_first_molar
            ToothKind.SECOND_MOLAR -> R.string.kind_second_molar
        },
    )
    return context.getString(R.string.tooth_full_name, arch, side, kind)
        .replaceFirstChar { character -> character.uppercase() }
}

package com.bnjdpn.petitesdents.ui

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
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
            Column(modifier = Modifier.padding(vertical = 16.dp)) {
                ToothArchDiagram(
                    title = stringResource(R.string.upper_arch),
                    teeth = teeth.filter { it.definition.arch == ToothArch.UPPER },
                    arch = ToothArch.UPPER,
                    onSelect = onSelect,
                )

                ToothArchDiagram(
                    title = stringResource(R.string.lower_arch),
                    teeth = teeth.filter { it.definition.arch == ToothArch.LOWER },
                    arch = ToothArch.LOWER,
                    onSelect = onSelect,
                )
            }
        }

        Legend(modifier = Modifier.padding(top = 18.dp, bottom = 24.dp))
    }
}

@Composable
private fun ToothArchDiagram(
    title: String,
    teeth: List<ToothSnapshot>,
    arch: ToothArch,
    onSelect: (ToothSnapshot) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 2.dp),
        )
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            val diagramWidth = maxWidth
            val diagramHeight = DentalArchGeometry.heightForWidth(diagramWidth.value).dp
            val visualScale = (diagramWidth.value / 350f).coerceIn(0.92f, 2.40f)
            val touchWidth = maxOf(48f, 40f * visualScale).dp
            val touchHeight = maxOf(56f, 52f * visualScale).dp
            val placements = DentalArchGeometry.placements(arch)
            val teethByFdi = teeth.associateBy { it.definition.fdi }
            val positionedTeeth = DentalArchGeometry.expectedFdis(arch).mapIndexedNotNull { index, fdi ->
                teethByFdi[fdi]?.let { index to it }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(diagramHeight),
            ) {
                Canvas(modifier = Modifier.matchParentSize()) {
                    drawPath(
                        path = gumPath(size, arch),
                        color = CoralSoft.copy(alpha = 0.72f),
                        style = Stroke(
                            width = 42.dp.toPx() * visualScale,
                            cap = StrokeCap.Round,
                            join = StrokeJoin.Round,
                        ),
                    )
                }

                positionedTeeth.forEach { (index, tooth) ->
                    val placement = placements[index]
                    ToothButton(
                        tooth = tooth,
                        toothRotation = placement.rotationDegrees,
                        visualScale = visualScale,
                        touchWidth = touchWidth,
                        touchHeight = touchHeight,
                        onClick = { onSelect(tooth) },
                        modifier = Modifier.absoluteOffset(
                            x = (diagramWidth.value * placement.xFraction).dp - touchWidth / 2,
                            y = (diagramHeight.value * placement.yFraction).dp - touchHeight / 2,
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun ToothButton(
    tooth: ToothSnapshot,
    toothRotation: Float,
    visualScale: Float,
    touchWidth: Dp,
    touchHeight: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val name = tooth.definition.localizedName(context)
    val state = stringResource(tooth.record.status.stringResource)
    val description = stringResource(
        R.string.tooth_accessibility,
        name,
        tooth.definition.fdi,
        state,
    )
    val fill = when (tooth.record.status) {
        ToothStatus.GHOST -> GhostFill
        ToothStatus.TEETHING -> Apricot
        ToothStatus.ERUPTED -> Sage.copy(alpha = 0.30f)
    }
    val strokeColor = tooth.definition.kind.familyOutline.color
    val (toothWidth, toothHeight) = toothVisualSize(tooth.definition.kind, visualScale)

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(width = touchWidth, height = touchHeight)
            .testTag("tooth-${tooth.definition.fdi}")
            .semantics(mergeDescendants = true) {
                contentDescription = description
                stateDescription = state
            }
            .clickable(onClick = onClick),
    ) {
        Canvas(
            modifier = Modifier
                .size(width = toothWidth, height = toothHeight)
                .rotate(toothRotation),
        ) {
            val path = toothPath(size, tooth.definition.kind)
            drawPath(path, color = fill, style = Fill)
            drawPath(
                path = path,
                color = strokeColor,
                style = Stroke(
                    width = 2.5.dp.toPx(),
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

private fun toothVisualSize(kind: ToothKind, scale: Float): Pair<Dp, Dp> {
    val (width, height) = when (kind) {
        ToothKind.CENTRAL_INCISOR -> 27f to 39f
        ToothKind.LATERAL_INCISOR -> 24f to 37f
        ToothKind.CANINE -> 26f to 41f
        ToothKind.FIRST_MOLAR -> 31f to 40f
        ToothKind.SECOND_MOLAR -> 34f to 43f
    }
    return (width * scale).dp to (height * scale).dp
}

private fun gumPath(size: Size, arch: ToothArch): Path = Path().apply {
    val outerY = if (arch == ToothArch.UPPER) size.height * 0.76f else size.height * 0.24f
    val shoulderY = if (arch == ToothArch.UPPER) size.height * 0.43f else size.height * 0.57f
    val centerY = if (arch == ToothArch.UPPER) size.height * 0.235f else size.height * 0.765f

    moveTo(size.width * 0.090f, outerY)
    cubicTo(
        size.width * 0.12f,
        shoulderY,
        size.width * 0.28f,
        centerY,
        size.width * 0.50f,
        centerY,
    )
    cubicTo(
        size.width * 0.72f,
        centerY,
        size.width * 0.88f,
        shoulderY,
        size.width * 0.910f,
        outerY,
    )
}

private fun toothPath(size: Size, kind: ToothKind): Path = when (kind) {
    ToothKind.CENTRAL_INCISOR, ToothKind.LATERAL_INCISOR -> incisorPath(size)
    ToothKind.CANINE -> caninePath(size)
    ToothKind.FIRST_MOLAR, ToothKind.SECOND_MOLAR -> molarPath(size)
}

private fun incisorPath(size: Size): Path = Path().apply {
    val w = size.width
    val h = size.height
    moveTo(w * 0.50f, h * 0.04f)
    cubicTo(w * 0.28f, -h * 0.01f, w * 0.10f, h * 0.11f, w * 0.14f, h * 0.29f)
    cubicTo(w * 0.17f, h * 0.49f, w * 0.28f, h * 0.70f, w * 0.40f, h * 0.94f)
    cubicTo(w * 0.44f, h * 1.01f, w * 0.56f, h * 1.01f, w * 0.60f, h * 0.94f)
    cubicTo(w * 0.72f, h * 0.70f, w * 0.83f, h * 0.49f, w * 0.86f, h * 0.29f)
    cubicTo(w * 0.90f, h * 0.11f, w * 0.72f, -h * 0.01f, w * 0.50f, h * 0.04f)
    close()
}

private fun caninePath(size: Size): Path = Path().apply {
    val w = size.width
    val h = size.height
    moveTo(w * 0.50f, h * 0.01f)
    cubicTo(w * 0.40f, h * 0.10f, w * 0.10f, h * 0.13f, w * 0.13f, h * 0.34f)
    cubicTo(w * 0.17f, h * 0.56f, w * 0.31f, h * 0.77f, w * 0.43f, h * 0.96f)
    cubicTo(w * 0.46f, h * 1.01f, w * 0.54f, h * 1.01f, w * 0.57f, h * 0.96f)
    cubicTo(w * 0.69f, h * 0.77f, w * 0.83f, h * 0.56f, w * 0.87f, h * 0.34f)
    cubicTo(w * 0.90f, h * 0.13f, w * 0.60f, h * 0.10f, w * 0.50f, h * 0.01f)
    close()
}

private fun molarPath(size: Size): Path = Path().apply {
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
                                    ToothStatus.GHOST -> GhostFill
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

package com.bnjdpn.petitesdents.export

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import com.bnjdpn.petitesdents.R
import com.bnjdpn.petitesdents.data.ToothArch
import com.bnjdpn.petitesdents.data.ToothSnapshot
import com.bnjdpn.petitesdents.data.ToothStatus
import com.bnjdpn.petitesdents.ui.formatEpochDay
import com.bnjdpn.petitesdents.ui.localizedName
import java.io.File
import java.io.FileOutputStream
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

object TeethPdfExporter {
    private const val PAGE_WIDTH = 595
    private const val PAGE_HEIGHT = 842
    private const val MARGIN = 42f

    fun create(context: Context, teeth: List<ToothSnapshot>): File {
        require(teeth.size == 20) { "The PDF requires the complete 20-tooth catalog" }
        val document = PdfDocument()
        val outputDirectory = File(context.cacheDir, "exports").apply { mkdirs() }
        val output = File(outputDirectory, context.getString(R.string.pdf_filename))

        try {
            val writer = PdfWriter(context, document)
            writer.render(teeth)
            FileOutputStream(output).use(document::writeTo)
        } finally {
            document.close()
        }
        return output
    }

    private class PdfWriter(
        private val context: Context,
        private val document: PdfDocument,
    ) {
        private val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(52, 44, 42)
            textSize = 22f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        private val headingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(52, 44, 42)
            textSize = 14f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(75, 66, 63)
            textSize = 10.5f
        }
        private val mutedPaint = Paint(bodyPaint).apply { color = Color.rgb(118, 105, 101) }
        private var pageNumber = 0
        private lateinit var page: PdfDocument.Page
        private var y = MARGIN

        fun render(teeth: List<ToothSnapshot>) {
            startPage()
            page.canvas.drawText(context.getString(R.string.pdf_title), MARGIN, y, titlePaint)
            y += 25f
            val generated = LocalDate.now().format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG))
            page.canvas.drawText(context.getString(R.string.pdf_generated, generated), MARGIN, y, mutedPaint)
            y += 26f

            val erupted = teeth.count { it.record.status == ToothStatus.ERUPTED }
            val teething = teeth.count { it.record.status == ToothStatus.TEETHING }
            val ghost = teeth.size - erupted - teething
            page.canvas.drawText(
                context.getString(R.string.pdf_summary, erupted, teething, ghost),
                MARGIN,
                y,
                headingPaint,
            )
            y += 24f
            drawMouth(teeth)
            y += 22f
            page.canvas.drawText(context.getString(R.string.history_title), MARGIN, y, headingPaint)
            y += 19f

            teeth.sortedWith(
                compareBy<ToothSnapshot> { it.definition.arch }
                    .thenBy { it.definition.fdi },
            ).forEach(::drawTooth)
            finishPage()
        }

        private fun drawMouth(teeth: List<ToothSnapshot>) {
            val cellWidth = (PAGE_WIDTH - MARGIN * 2) / 10f
            listOf(ToothArch.UPPER, ToothArch.LOWER).forEachIndexed { row, arch ->
                teeth.filter { it.definition.arch == arch }.forEachIndexed { index, tooth ->
                    val cx = MARGIN + cellWidth * index + cellWidth / 2f
                    val cy = y + row * 48f
                    val fill = when (tooth.record.status) {
                        ToothStatus.GHOST -> Color.rgb(238, 232, 228)
                        ToothStatus.TEETHING -> Color.rgb(255, 215, 188)
                        ToothStatus.ERUPTED -> Color.rgb(129, 155, 122)
                    }
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill }
                    page.canvas.drawRoundRect(cx - 15f, cy, cx + 15f, cy + 30f, 9f, 9f, paint)
                    val label = Paint(bodyPaint).apply {
                        textAlign = Paint.Align.CENTER
                        textSize = 8f
                        color = if (tooth.record.status == ToothStatus.ERUPTED) Color.WHITE else Color.DKGRAY
                    }
                    page.canvas.drawText(tooth.definition.fdi.toString(), cx, cy + 19f, label)
                }
            }
            y += 92f
        }

        private fun drawTooth(tooth: ToothSnapshot) {
            val noteLines = wrap(tooth.record.note, 82)
            val requiredHeight = 46f + noteLines.size * 13f
            ensureSpace(requiredHeight)

            page.canvas.drawText(
                "${tooth.definition.fdi} · ${tooth.definition.localizedName(context)}",
                MARGIN,
                y,
                headingPaint,
            )
            y += 15f
            val teething = tooth.record.teethingEpochDay?.let(::formatEpochDay)
                ?: context.getString(R.string.pdf_no_date)
            val erupted = tooth.record.eruptedEpochDay?.let(::formatEpochDay)
                ?: context.getString(R.string.pdf_no_date)
            page.canvas.drawText(context.getString(R.string.pdf_teething, teething), MARGIN + 8f, y, bodyPaint)
            page.canvas.drawText(context.getString(R.string.pdf_erupted, erupted), 300f, y, bodyPaint)
            y += 14f
            if (noteLines.isNotEmpty()) {
                noteLines.forEachIndexed { index, line ->
                    val value = if (index == 0) context.getString(R.string.pdf_note, line) else line
                    page.canvas.drawText(value, MARGIN + 8f, y, mutedPaint)
                    y += 13f
                }
            }
            y += 10f
        }

        private fun wrap(text: String, maxCharacters: Int): List<String> {
            if (text.isBlank()) return emptyList()
            val lines = mutableListOf<String>()
            var current = StringBuilder()
            text.trim().split(Regex("\\s+")).forEach { word ->
                if (current.isNotEmpty() && current.length + word.length + 1 > maxCharacters) {
                    lines += current.toString()
                    current = StringBuilder()
                }
                if (current.isNotEmpty()) current.append(' ')
                current.append(word)
            }
            if (current.isNotEmpty()) lines += current.toString()
            return lines
        }

        private fun ensureSpace(height: Float) {
            if (y + height <= PAGE_HEIGHT - MARGIN) return
            finishPage()
            startPage()
        }

        private fun startPage() {
            pageNumber += 1
            page = document.startPage(
                PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create(),
            )
            y = MARGIN
        }

        private fun finishPage() {
            val footer = Paint(mutedPaint).apply {
                textAlign = Paint.Align.RIGHT
                textSize = 9f
            }
            page.canvas.drawText(pageNumber.toString(), PAGE_WIDTH - MARGIN, PAGE_HEIGHT - 20f, footer)
            document.finishPage(page)
        }
    }
}

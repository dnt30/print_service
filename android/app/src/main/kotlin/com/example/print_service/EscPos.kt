package com.example.print_service

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.print.PageRange
import java.io.OutputStream
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

object EscPos {
    private const val PDF_ZOOM = 1.05f

    fun dots(paperMm: Int): Int {
        require(paperMm == 58 || paperMm == 80) { "Ukuran kertas tidak didukung." }
        return if (paperMm == 80) 576 else 384
    }

    /** GS v 0, 1-bit raster, streamed in small strips for printer buffers. */
    fun raster(bitmap: Bitmap, output: OutputStream, control: JobControl) {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val packet = RasterEncoder.encode(bitmap.width, bitmap.height, pixels)
        for (offset in packet.indices step 512) {
            control.check()
            output.write(packet, offset, min(512, packet.size - offset))
            output.flush()
            Thread.sleep(20)
        }
    }

    fun text(text: String, paperMm: Int, output: OutputStream, control: JobControl) {
        require(text.isNotBlank() && text.length <= 12000) { "Teks harus berisi 1–12.000 karakter." }
        val width = dots(paperMm)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textSize = 19f
            typeface = Typeface.MONOSPACE
        }
        val lines = mutableListOf<String>()
        for (line in text.replace("\r\n", "\n").replace('\r', '\n').split('\n')) {
            var remainder = line.replace("\t", "    ")
            if (remainder.isEmpty()) lines.add("")
            while (remainder.isNotEmpty()) {
                var count = paint.breakText(remainder, true, (width - 16).toFloat(), null).coerceAtLeast(1)
                if (count < remainder.length && Character.isHighSurrogate(remainder[count - 1])) count--
                count = count.coerceAtLeast(1)
                lines.add(remainder.take(count))
                remainder = remainder.drop(count)
            }
        }
        for (chunk in lines.chunked(8)) {
            control.check()
            val bitmap = Bitmap.createBitmap(width, chunk.size * 28, Bitmap.Config.ARGB_8888)
            try {
                val canvas = Canvas(bitmap)
                canvas.drawColor(Color.WHITE)
                chunk.forEachIndexed { index, line -> canvas.drawText(line, 8f, index * 28f + 21f, paint) }
                raster(bitmap, output, control)
            } finally { bitmap.recycle() }
        }
    }

    fun pdf(fd: ParcelFileDescriptor, paperMm: Int, copies: Int, output: OutputStream, control: JobControl, cut: Boolean, ranges: Array<PageRange>? = null) {
        PdfRenderer(fd).use { renderer ->
            pdf(renderer, paperMm, copies, output, control, cut, ranges)
        }
    }

    fun pdf(renderer: PdfRenderer, paperMm: Int, copies: Int, output: OutputStream, control: JobControl, cut: Boolean, ranges: Array<PageRange>? = null) {
        require(renderer.pageCount in 1..200) { "Dokumen harus berisi 1–200 halaman." }
        val layouts = mutableMapOf<Int, PdfLayout>()
        repeat(copies) {
            for (pageIndex in 0 until renderer.pageCount) {
                if (!ranges.isNullOrEmpty() && ranges.none { pageIndex in it.start..it.end }) continue
                control.check()
                renderer.openPage(pageIndex).use { page ->
                    val width = dots(paperMm)
                    val layout = layouts.getOrPut(pageIndex) { pdfLayout(page, width, control) }
                    val scale = layout.scale
                    val height = ceil(page.height * scale).toInt()
                    require(height in 1..100000) { "Halaman terlalu panjang untuk dicetak." }
                    var pendingBlank = 0
                    for (top in 0 until height step 128) {
                        control.check()
                        val rows = min(128, height - top)
                        val bitmap = Bitmap.createBitmap(width, rows, Bitmap.Config.ARGB_8888)
                        try {
                            bitmap.eraseColor(Color.WHITE)
                            val matrix = Matrix().apply { setScale(scale, scale); postTranslate(layout.offsetX, -top.toFloat()) }
                            page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                            val lastInk = lastInkRow(bitmap)
                            if (lastInk < 0) pendingBlank += rows
                            else {
                                feed(output, pendingBlank, control)
                                pendingBlank = 0
                                // Trim the blank tail; preserve it only if more content follows.
                                val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, lastInk + 1)
                                try { raster(cropped, output, control) }
                                finally { if (cropped !== bitmap) cropped.recycle() }
                                pendingBlank = rows - lastInk - 1
                            }
                        } finally { bitmap.recycle() }
                    }
                }
            }
            finish(output, cut)
        }
    }

    private data class PdfLayout(val scale: Float, val offsetX: Float)

    /** Use blank side margins for a small enlargement, capped to keep all ink on paper. */
    private fun pdfLayout(page: PdfRenderer.Page, width: Int, control: JobControl): PdfLayout {
        val baseScale = width.toFloat() / page.width
        val height = ceil(page.height * baseScale).toInt()
        require(height in 1..100000) { "Halaman terlalu panjang untuk dicetak." }
        var firstInk = width
        var lastInk = -1
        val pixels = IntArray(width * 128)
        for (top in 0 until height step 128) {
            control.check()
            val rows = min(128, height - top)
            val bitmap = Bitmap.createBitmap(width, rows, Bitmap.Config.ARGB_8888)
            try {
                bitmap.eraseColor(Color.WHITE)
                val matrix = Matrix().apply { setScale(baseScale, baseScale); postTranslate(0f, -top.toFloat()) }
                page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                bitmap.getPixels(pixels, 0, width, 0, 0, width, rows)
                for (index in 0 until width * rows) {
                    if (RasterEncoder.isInk(pixels[index])) {
                        val x = index % width
                        firstInk = min(firstInk, x)
                        lastInk = max(lastInk, x)
                    }
                }
            } finally { bitmap.recycle() }
            if (firstInk == 0 && lastInk == width - 1) break
        }
        if (lastInk < 0) return PdfLayout(baseScale, 0f)
        // Leave a two-dot guard for rounding and antialiasing at the new scale.
        val left = (firstInk - 2).coerceAtLeast(0)
        val right = (lastInk + 3).coerceAtMost(width)
        val zoom = min(PDF_ZOOM, width.toFloat() / (right - left))
        val minOffset = -left * zoom
        val maxOffset = (width - right * zoom).coerceAtLeast(minOffset)
        val offset = ((width - width * zoom) / 2).coerceIn(minOffset, maxOffset)
        return PdfLayout(baseScale * zoom, offset)
    }

    private fun lastInkRow(bitmap: Bitmap): Int {
        val row = IntArray(bitmap.width)
        for (y in bitmap.height - 1 downTo 0) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            if (row.any { RasterEncoder.isInk(it) }) return y
        }
        return -1
    }

    private fun feed(output: OutputStream, dots: Int, control: JobControl) {
        var remaining = dots
        while (remaining > 0) {
            control.check()
            val step = min(255, remaining)
            output.write(byteArrayOf(0x1b, 0x4a, step.toByte()))
            remaining -= step
        }
    }

    fun finish(output: OutputStream, cut: Boolean) {
        output.write(byteArrayOf(0x1b, 0x64, 4))
        if (cut) output.write(byteArrayOf(0x1d, 0x56, 0x42, 0))
        output.flush()
    }
}

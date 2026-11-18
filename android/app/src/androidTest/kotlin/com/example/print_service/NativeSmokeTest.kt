package com.example.print_service

import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.ParcelFileDescriptor
import android.print.PageRange
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.io.ByteArrayOutputStream
import kotlin.math.abs

class NativeSmokeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    @Test fun pdfEnlargesReceiptContentByFivePercentOnBothPaperWidths() {
        for ((paper, pageWidth) in listOf(58 to 164, 80 to 227)) {
            val bytes = renderRectangle(paper, pageWidth, 20f, 100f)
            val width = EscPos.dots(paper)
            val bounds = rasterInkBounds(bytes, width)
            val expectedWidth = 80f * width / pageWidth * 1.05f
            assertTrue("Receipt should be enlarged by 5%", abs(bounds.second - bounds.first + 1 - expectedWidth) <= 2)
            val rows = (bytes[6].toInt() and 255) + ((bytes[7].toInt() and 255) shl 8)
            assertTrue("Vertical scale should match horizontal scale", abs(rows - 20f * width / pageWidth * 1.05f) <= 2)
        }
    }

    @Test fun pdfKeepsContentAtBothEdgesWhenThereIsNoRoomToEnlarge() {
        for ((paper, pageWidth) in listOf(58 to 164, 80 to 227)) {
            val bytes = renderRectangle(paper, pageWidth, 0f, pageWidth.toFloat())
            val width = EscPos.dots(paper)
            assertEquals(0 to width - 1, rasterInkBounds(bytes, width))
            val rows = (bytes[6].toInt() and 255) + ((bytes[7].toInt() and 255) shl 8)
            assertTrue("Full-width content must retain its scale", abs(rows - 20f * width / pageWidth) <= 2)
        }
    }

    @Test fun pdfCanEnlargeLeftAlignedContentWithoutCuttingItsLeftEdge() {
        val bytes = renderRectangle(58, 164, 0f, 80f)
        val bounds = rasterInkBounds(bytes, 384)
        assertEquals(0, bounds.first)
        assertTrue(abs(bounds.second + 1 - 80f * 384 / 164 * 1.05f) <= 2)
    }

    private fun renderRectangle(paper: Int, pageWidth: Int, left: Float, right: Float): ByteArray {
        val file = File.createTempFile("scale-test-", ".pdf", context.cacheDir)
        try {
            val document = PdfDocument()
            try {
                val page = document.startPage(PdfDocument.PageInfo.Builder(pageWidth, 80, 1).create())
                page.canvas.drawRect(left, 10f, right, 20f, Paint().apply { color = Color.BLACK })
                document.finishPage(page)
                file.outputStream().use { document.writeTo(it) }
            } finally { document.close() }
            val output = ByteArrayOutputStream()
            EscPos.pdf(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY), paper, 1,
                output, JobControl(), false)
            return output.toByteArray()
        } finally { file.delete() }
    }

    private fun rasterInkBounds(bytes: ByteArray, width: Int): Pair<Int, Int> {
        assertArrayEquals(byteArrayOf(0x1d, 0x76, 0x30, 0), bytes.take(4).toByteArray())
        val widthBytes = (bytes[4].toInt() and 255) + ((bytes[5].toInt() and 255) shl 8)
        val rows = (bytes[6].toInt() and 255) + ((bytes[7].toInt() and 255) shl 8)
        assertEquals(width, widthBytes * 8)
        assertEquals("Fixture must produce one raster strip and a feed", 8 + widthBytes * rows + 3, bytes.size)
        var left = width
        var right = -1
        for (y in 0 until rows) for (x in 0 until width) {
            if ((bytes[8 + y * widthBytes + x / 8].toInt() and (0x80 shr (x % 8))) != 0) {
                left = minOf(left, x)
                right = maxOf(right, x)
            }
        }
        return left to right
    }

    @Test fun pdfHonorsPageSelectionAndTrimsEmptyTail() {
        val file = File(context.cacheDir, "smoke-receipt.pdf")
        try {
            val document = PdfDocument()
            try {
                repeat(2) { index ->
                    val page = document.startPage(PdfDocument.PageInfo.Builder(164, 850, index + 1).create())
                    page.canvas.drawRect(8f, 10f, 100f, 20f, Paint().apply { color = Color.BLACK })
                    document.finishPage(page)
                }
                file.outputStream().use { document.writeTo(it) }
            } finally { document.close() }
            val output = ByteArrayOutputStream()
            EscPos.pdf(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY), 58, 1,
                output, JobControl(), false, arrayOf(PageRange(1, 1)))
            val bytes = output.toByteArray()
            assertArrayEquals(byteArrayOf(0x1d, 0x76, 0x30, 0), bytes.take(4).toByteArray())
            val widthBytes = (bytes[4].toInt() and 255) + ((bytes[5].toInt() and 255) shl 8)
            val rows = (bytes[6].toInt() and 255) + ((bytes[7].toInt() and 255) shl 8)
            assertEquals(48, widthBytes)
            assertTrue(rows in 1..128)
            // Exactly one raster block and a feed: the other page and blank page tail were omitted.
            assertEquals(8 + widthBytes * rows + 3, bytes.size)
            assertArrayEquals(byteArrayOf(0x1b, 0x64, 4), bytes.takeLast(3).toByteArray())
        } finally { file.delete() }
    }

    @Test fun serviceRequiresSystemBindingPermission() {
        val service = context.packageManager.getServiceInfo(ComponentName(context, PosPrintService::class.java), 0)
        assertTrue(service.exported)
        assertEquals("android.permission.BIND_PRINT_SERVICE", service.permission)
    }

    @Test fun printerHistoryAndPreferencesPersist() {
        val isolated = object : ContextWrapper(context) {
            override fun getSharedPreferences(name: String, mode: Int) = super.getSharedPreferences("smoke_$name", mode)
        }
        val prefs = isolated.getSharedPreferences("print_service", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        try {
            assertEquals(58, StateStore.paper(isolated))
            StateStore.select(isolated, "00:11:22:33:44:55", "Test POS")
            StateStore.preferences(isolated, mapOf("paperMm" to 80, "cutPaper" to true))
            StateStore.record(isolated, "Uji", "Test POS", 80, "sent")
            val state = StateStore.snapshot(isolated)
            assertEquals("00:11:22:33:44:55", state["selectedAddress"])
            assertEquals(80, StateStore.paper(isolated))
            assertTrue(StateStore.cut(isolated))
            assertEquals(1, (state["records"] as List<*>).size)
            StateStore.forget(isolated, "00:11:22:33:44:55")
            assertNull(StateStore.snapshot(isolated)["selectedAddress"])
        } finally { prefs.edit().clear().commit() }
    }

    @Test fun websiteUsesAnExternalBrowsableIntent() {
        val intent = BrowserLauncher.intent("http://192.168.1.10/kasir")
        assertEquals(Intent.ACTION_VIEW, intent.action)
        assertTrue(intent.hasCategory(Intent.CATEGORY_BROWSABLE))
        assertNull(intent.component)
        assertNull(intent.`package`)
        assertEquals("192.168.1.10", intent.data?.host)
    }

    @Test(expected = IllegalArgumentException::class)
    fun externalBrowserRejectsExecutableUrls() {
        BrowserLauncher.intent("javascript:alert(1)")
    }
}

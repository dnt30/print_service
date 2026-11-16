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

class NativeSmokeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

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

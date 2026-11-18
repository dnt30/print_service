package com.example.print_service

import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class SpoolDocumentTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun rendersPdfReceivedThroughSpoolerPipe() {
        val document = PdfDocument()
        val bytes = ByteArrayOutputStream()
        try {
            val page = document.startPage(PdfDocument.PageInfo.Builder(164, 850, 1).create())
            page.canvas.drawRect(8f, 10f, 100f, 20f, Paint().apply { color = Color.BLACK })
            document.finishPage(page)
            document.writeTo(bytes)
        } finally { document.close() }
        // Exceed the pipe buffer to ensure the reader consumes the complete stream.
        bytes.write(ByteArray(128 * 1024) { ' '.code.toByte() })
        val pipe = ParcelFileDescriptor.createPipe()
        val worker = Executors.newSingleThreadExecutor()
        try {
            val writer = worker.submit {
                ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { it.write(bytes.toByteArray()) }
            }
            val output = ByteArrayOutputStream()
            withCacheDirectory { directory ->
                val control = JobControl()
                SpoolDocument.withRenderer(pipe[0], directory, control) { renderer ->
                    EscPos.pdf(renderer, 58, 1, output, control, false)
                }
            }
            writer.get(5, TimeUnit.SECONDS)
            val raster = output.toByteArray()
            assertArrayEquals(byteArrayOf(0x1d, 0x76, 0x30, 0), raster.take(4).toByteArray())
            assertEquals(48, raster[4].toInt() and 255)
            assertTrue(raster.drop(8).dropLast(3).any { it != 0.toByte() })
        } finally {
            pipe.forEach { runCatching { it.close() } }
            worker.shutdownNow()
        }
    }

    @Test fun invalidPdfFailsBeforeSendingAndDeletesTemporaryFile() {
        val pipe = ParcelFileDescriptor.createPipe()
        try {
            ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { it.write("invalid PDF".toByteArray()) }
            withCacheDirectory { directory ->
                try {
                    SpoolDocument.withRenderer(pipe[0], directory, JobControl()) {
                        fail("Invalid PDF must not reach the printer")
                    }
                    fail("Expected a document error")
                } catch (e: IOException) {
                    assertTrue(e.message.orEmpty().contains("PDF"))
                }
            }
        } finally { pipe.forEach { runCatching { it.close() } } }
    }

    @Test fun cancelledReceptionDoesNotSendToPrinter() {
        val pipe = ParcelFileDescriptor.createPipe()
        try {
            withCacheDirectory { directory ->
                val control = JobControl().apply { cancel() }
                try {
                    SpoolDocument.withRenderer(pipe[0], directory, control) {
                        fail("Cancelled document must not reach the printer")
                    }
                    fail("Expected cancellation")
                } catch (_: PrintCancelled) { /* Expected. */ }
            }
        } finally { pipe.forEach { runCatching { it.close() } } }
    }

    @Test(timeout = 10000) fun cancellationDuringReceptionDeletesPartialDocument() {
        val pipe = ParcelFileDescriptor.createPipe()
        val worker = Executors.newSingleThreadExecutor()
        val control = JobControl()
        try {
            val writer = worker.submit {
                ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use {
                    it.write(ByteArray(128 * 1024))
                    control.cancel()
                }
            }
            withCacheDirectory { directory ->
                try {
                    SpoolDocument.withRenderer(pipe[0], directory, control) {
                        fail("Cancelled document must not reach the printer")
                    }
                    fail("Expected cancellation")
                } catch (_: PrintCancelled) { /* Expected. */ }
            }
            writer.get(5, TimeUnit.SECONDS)
        } finally {
            pipe.forEach { runCatching { it.close() } }
            worker.shutdownNow()
        }
    }

    private fun withCacheDirectory(block: (File) -> Unit) {
        val directory = File(context.cacheDir, "spool-test-${System.nanoTime()}")
        assertTrue(directory.mkdir())
        try {
            block(directory)
        } finally {
            val remaining = directory.listFiles().orEmpty()
            remaining.forEach { it.delete() }
            directory.delete()
            assertTrue("Temporary print documents must be deleted", remaining.isEmpty())
        }
    }
}

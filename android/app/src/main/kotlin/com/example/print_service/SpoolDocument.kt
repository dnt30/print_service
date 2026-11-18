package com.example.print_service

import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.IOException

/** Android's print spooler supplies a pipe; PdfRenderer requires a seekable file. */
object SpoolDocument {
    fun <T> withRenderer(source: ParcelFileDescriptor, cacheDir: File, control: JobControl,
                         block: (PdfRenderer) -> T): T {
        var temporary: File? = null
        try {
            val document = ParcelFileDescriptor.AutoCloseInputStream(source).use { input ->
                control.attach(input)
                try {
                    control.check()
                    val file = File.createTempFile("print-spool-", ".pdf", cacheDir)
                    temporary = file
                    file.outputStream().use { output ->
                        val buffer = ByteArray(32 * 1024)
                        while (true) {
                            control.check()
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                    }
                    control.check()
                    file
                } catch (e: Exception) {
                    control.check()
                    throw IOException("Gagal menerima dokumen cetak dari Android. Coba cetak ulang dari browser.", e)
                } finally { control.detach() }
            }
            control.check()
            ParcelFileDescriptor.open(document, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                val renderer = try { PdfRenderer(fd) }
                catch (e: Exception) {
                    throw IOException("Dokumen cetak tidak dapat dibaca sebagai PDF. Coba cetak ulang dari browser.", e)
                }
                return renderer.use {
                    control.check()
                    block(it)
                }
            }
        } finally { temporary?.delete() }
    }
}

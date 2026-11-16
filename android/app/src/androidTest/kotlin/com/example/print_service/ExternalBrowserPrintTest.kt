package com.example.print_service

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.Closeable
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern

/** Cross-app test on a disposable emulator: the page runs in real Chrome, not a WebView. */
class ExternalBrowserPrintTest {
    @Test fun chromePrintsThroughTheAndroidPrintFramework() {
        assumeTrue("Run browser setup only on an emulator", Build.HARDWARE in listOf("ranchu", "goldfish"))
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val device = UiDevice.getInstance(instrumentation)
        val component = ComponentName(context, PosPrintService::class.java).flattenToString()
        val resolver = context.contentResolver
        val key = "enabled_print_services"
        instrumentation.uiAutomation.adoptShellPermissionIdentity(Manifest.permission.WRITE_SECURE_SETTINGS)
        val original = Settings.Secure.getString(resolver, key)
        try {
            Settings.Secure.putString(resolver, key, (original.orEmpty().split(':').filter { it.isNotBlank() } + component).distinct().joinToString(":"))
            LocalReceipt().use { page ->
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(page.url)).setPackage("com.android.chrome").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try { context.startActivity(intent) }
                catch (e: android.content.ActivityNotFoundException) { assumeTrue("Chrome is required for this test", false) }

                val deadline = System.currentTimeMillis() + 30000
                val button = By.text("Cetak struk dari Chrome")
                while (!device.hasObject(button) && System.currentTimeMillis() < deadline) {
                    for (label in listOf("Stay signed out", "Use without an account", "Continue without an account", "Accept & continue", "No thanks", "Got it", "Not now")) {
                        device.findObject(By.text(label))?.click()
                    }
                    Thread.sleep(500)
                }
                assertTrue("Chrome did not load the local receipt", device.hasObject(button))
                device.findObject(button).click()
                var path = "window.print()"
                if (!device.wait(Until.hasObject(By.pkg("com.android.printspooler")), 8000)) {
                    path = "Chrome menu > Share > Print"
                    device.findObject(By.desc("More options"))?.click()
                    val share = device.wait(Until.findObject(By.text(Pattern.compile("Share.*"))), 5000)
                    assertNotNull("Chrome Share menu not available", share)
                    share!!.click()
                    val print = device.wait(Until.findObject(By.text("Print")), 5000)
                        ?: device.findObject(By.desc("Print"))
                    assertNotNull("Chrome Print action not available", print)
                    print!!.click()
                }
                assertTrue("Chrome did not open Android print dialog", device.wait(Until.hasObject(By.pkg("com.android.printspooler")), 10000))
                device.findObject(By.res("com.android.printspooler", "destination_spinner"))?.click()
                device.wait(Until.findObject(By.text(Pattern.compile("All printers.*"))), 3000)?.click()
                val dump = device.executeShellCommand("dumpsys print")
                assertTrue("Our service is missing from Android print services", dump.contains("com.example.print_service"))
                Log.i("ExternalPrintTest", "PASS: external Chrome -> $path -> Android dialog; Print Service registered")
                device.pressBack()
                device.pressBack()
            }
        } finally {
            Settings.Secure.putString(resolver, key, original)
            instrumentation.uiAutomation.dropShellPermissionIdentity()
            device.pressHome()
        }
    }

    private class LocalReceipt : Closeable {
        private val running = AtomicBoolean(true)
        private val server = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
        val url = "http://127.0.0.1:${server.localPort}/receipt"
        private val worker = Thread {
            while (running.get()) {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = 5000
                        val reader = socket.getInputStream().bufferedReader()
                        while (!reader.readLine().isNullOrEmpty()) { /* Read HTTP headers. */ }
                        val body = """<!doctype html><html><meta name="viewport" content="width=device-width,initial-scale=1"><title>External POS smoke</title><style>body{font:20px sans-serif;padding:24px}button{padding:24px}@media print{button{display:none}}</style><h1>TEST POS</h1><p>External browser receipt</p><button onclick="window.print()">Cetak struk dari Chrome</button></html>""".toByteArray(Charsets.UTF_8)
                        socket.getOutputStream().apply {
                            write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: ${body.size}\r\nConnection: close\r\n\r\n".toByteArray())
                            write(body); flush()
                        }
                    }
                } catch (e: Exception) { if (!running.get()) break }
            }
        }.apply { isDaemon = true; start() }

        override fun close() { running.set(false); server.close(); worker.join(1000) }
    }
}

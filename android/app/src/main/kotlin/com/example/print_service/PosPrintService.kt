package com.example.print_service

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log

class PosPrintService : PrintService() {
    private val main = Handler(Looper.getMainLooper())
    private val jobs = mutableMapOf<android.print.PrintJobId, JobControl>()

    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession = Discovery()

    @SuppressLint("MissingPermission")
    override fun onPrintJobQueued(job: PrintJob) {
        val address = job.info.printerId?.localId
        val attrs = job.info.attributes
        val paper = if ((attrs.mediaSize?.widthMils ?: 2283) > 2700) 80 else 58
        val name = address?.let { runCatching { BluetoothTransport.device(this, it).name }.getOrNull() }
            ?: address ?: "Printer Bluetooth"
        val title = job.info.label
        val copies = job.info.copies.coerceIn(1, 99)
        val ranges = job.info.pages
        if (address == null || !BluetoothTransport.permitted(this)) {
            val message = "Buka Print Service, izinkan akses Bluetooth, lalu pilih printer."
            StateStore.record(this, title, name, paper, "failed", message)
            job.fail(message)
            return
        }
        val fd = try { job.document.data } catch (e: Exception) { null }
        if (fd == null) {
            StateStore.record(this, title, name, paper, "failed", "Dokumen cetak tidak tersedia.")
            job.fail("Dokumen cetak tidak tersedia.")
            return
        }
        if (!job.start()) { fd.close(); return }
        val control = JobControl()
        jobs[job.id] = control
        BluetoothTransport.queue.execute {
            var status = "sent"
            var error: String? = null
            try {
                SpoolDocument.withRenderer(fd, cacheDir, control) { renderer ->
                    BluetoothTransport.send(this, address, control) { output ->
                        EscPos.pdf(renderer, paper, copies, output, control, StateStore.cut(this), ranges)
                    }
                }
                StateStore.select(this, address, name, used = true)
            } catch (e: PrintCancelled) {
                status = "cancelled"; error = e.message
            } catch (e: Exception) {
                Log.e("PosPrintService", "System print job failed", e)
                status = "failed"; error = e.message ?: "Gagal mencetak dokumen."
            }
            StateStore.record(this, title, name, paper, status, error)
            main.post {
                jobs.remove(job.id)
                when (status) {
                    "sent" -> if (job.isStarted) job.complete()
                    "cancelled" -> if (job.isStarted) job.cancel()
                    else -> if (job.isStarted) job.fail(error)
                }
            }
        }
    }

    override fun onRequestCancelPrintJob(job: PrintJob) { jobs[job.id]?.cancel() }

    override fun onDestroy() {
        jobs.values.forEach { it.cancel() }
        super.onDestroy()
    }

    private inner class Discovery : PrinterDiscoverySession() {
        private var registered = false
        private val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) { publish() }
        }

        @SuppressLint("MissingPermission", "UnspecifiedRegisterReceiverFlag")
        override fun onStartPrinterDiscovery(priorityList: MutableList<PrinterId>) {
            if (!registered) {
                val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED).apply { addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED) }
                if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                else registerReceiver(receiver, filter)
                registered = true
            }
            publish()
        }

        @SuppressLint("MissingPermission")
        private fun publish() {
            val saved = StateStore.printerAddresses(this@PosPrintService)
            val devices = runCatching { BluetoothTransport.paired(this@PosPrintService) }
                .getOrDefault(emptyList()).filter { it.address in saved }
            val currentIds = devices.map { generatePrinterId(it.address) }.toSet()
            removePrinters(printers.map { it.id }.filter { it !in currentIds })
            addPrinters(devices.map { device ->
                val id = generatePrinterId(device.address)
                val defaultPaper = StateStore.paper(this@PosPrintService)
                val capabilities = PrinterCapabilitiesInfo.Builder(id)
                    .addMediaSize(PrintAttributes.MediaSize("POS_58", "POS 58 mm", 2283, 11811), defaultPaper == 58)
                    .addMediaSize(PrintAttributes.MediaSize("POS_80", "POS 80 mm", 3150, 11811), defaultPaper == 80)
                    .addResolution(PrintAttributes.Resolution("thermal", "203 dpi", 203, 203), true)
                    .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                    .setColorModes(PrintAttributes.COLOR_MODE_MONOCHROME, PrintAttributes.COLOR_MODE_MONOCHROME)
                    .setDuplexModes(PrintAttributes.DUPLEX_MODE_NONE, PrintAttributes.DUPLEX_MODE_NONE)
                    .build()
                PrinterInfo.Builder(id, device.name ?: "Printer Bluetooth", PrinterInfo.STATUS_IDLE)
                    .setDescription("ESC/POS · ${device.address} · 58 / 80 mm")
                    .setCapabilities(capabilities).build()
            })
        }

        override fun onStopPrinterDiscovery() { unregister() }
        override fun onValidatePrinters(printerIds: MutableList<PrinterId>) { publish() }
        override fun onStartPrinterStateTracking(printerId: PrinterId) { publish() }
        override fun onStopPrinterStateTracking(printerId: PrinterId) = Unit
        override fun onDestroy() { unregister() }
        private fun unregister() {
            if (registered) { unregisterReceiver(receiver); registered = false }
        }
    }
}

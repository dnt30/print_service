package com.example.print_service

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.IOException
import java.io.OutputStream
import java.io.Closeable
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

object BluetoothTransport {
    // Serialize jobs across Flutter and the system service: bytes must never interleave.
    val queue = Executors.newSingleThreadExecutor()
    private val timer = Executors.newSingleThreadScheduledExecutor()
    private val spp = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    fun adapter(context: Context): BluetoothAdapter? = context.getSystemService(BluetoothManager::class.java)?.adapter
    fun permitted(context: Context): Boolean = Build.VERSION.SDK_INT < 31 ||
        context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    fun paired(context: Context): List<BluetoothDevice> {
        check(permitted(context)) { "Izinkan akses perangkat terdekat melalui aplikasi Print Service." }
        val adapter = adapter(context) ?: error("Perangkat ini tidak mendukung Bluetooth.")
        check(adapter.isEnabled) { "Bluetooth nonaktif. Nyalakan melalui pengaturan perangkat." }
        return adapter.bondedDevices.sortedBy { it.name ?: it.address }
    }

    @SuppressLint("MissingPermission")
    fun device(context: Context, address: String): BluetoothDevice {
        require(BluetoothAdapter.checkBluetoothAddress(address)) { "Alamat Bluetooth tidak valid." }
        return paired(context).find { it.address == address }
            ?: error("Printer belum dipasangkan. Buka pengaturan Bluetooth dan pasangkan printer dahulu.")
    }

    @SuppressLint("MissingPermission")
    fun send(context: Context, address: String, control: JobControl, block: (OutputStream) -> Unit) {
        val device = device(context, address)
        val socket = device.createRfcommSocketToServiceRecord(spp)
        control.attach(socket)
        val timedOut = AtomicBoolean(false)
        val connectTimeout = timer.schedule({
            timedOut.set(true)
            runCatching { socket.close() }
        }, 15, TimeUnit.SECONDS)
        try {
            control.check()
            socket.connect()
            connectTimeout.cancel(false)
            if (timedOut.get()) throw IOException("Koneksi printer melewati batas waktu.")
            // A blocked write must not stall every subsequent job indefinitely.
            val writeTimeout = timer.schedule({
                timedOut.set(true)
                runCatching { socket.close() }
            }, 180, TimeUnit.SECONDS)
            try {
                val stream = socket.outputStream
                stream.write(byteArrayOf(0x1b, 0x40))
                block(stream)
                control.check()
                stream.flush()
                // Allow low-cost printer buffers to consume the last packet before closing RFCOMM.
                Thread.sleep(300)
            } finally {
                writeTimeout.cancel(false)
            }
        } catch (e: Exception) {
            control.check()
            if (timedOut.get()) throw IOException("Printer tidak merespons. Periksa daya dan jarak Bluetooth.", e)
            throw IOException("Gagal mengirim ke printer. Periksa koneksi, lalu coba lagi. Sebagian struk mungkin sudah tercetak.", e)
        } finally {
            connectTimeout.cancel(false)
            runCatching { socket.close() }
            control.detach()
        }
    }
}

class JobControl {
    private val cancelled = AtomicBoolean(false)
    @Volatile private var resource: Closeable? = null
    fun attach(value: Closeable) { resource = value; if (cancelled.get()) runCatching { value.close() } }
    fun detach() { resource = null }
    fun cancel() { cancelled.set(true); runCatching { resource?.close() } }
    fun check() { if (cancelled.get()) throw PrintCancelled() }
}

class PrintCancelled : IOException("Cetakan dibatalkan. Sebagian struk mungkin sudah tercetak.")

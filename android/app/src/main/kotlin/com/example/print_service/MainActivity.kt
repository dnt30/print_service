package com.example.print_service

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: (() -> Unit)? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.printservice/native")
            .setMethodCallHandler { call, result ->
                try { handle(call, result) }
                catch (e: Exception) { result.error("native_error", e.message, null) }
            }
    }

    @SuppressLint("MissingPermission")
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> {
                val state = StateStore.snapshot(this).toMutableMap()
                state["permissionGranted"] = BluetoothTransport.permitted(this)
                state["bluetoothEnabled"] = BluetoothTransport.permitted(this) && BluetoothTransport.adapter(this)?.isEnabled == true
                val enabled = Settings.Secure.getString(contentResolver, "enabled_print_services").orEmpty()
                state["serviceEnabled"] = enabled.split(':').any {
                    android.content.ComponentName.unflattenFromString(it)?.className == PosPrintService::class.java.name
                }
                result.success(state)
            }
            "getPairedPrinters" -> withPermission(result) {
                try {
                    result.success(BluetoothTransport.paired(this).map {
                        mapOf("address" to it.address, "name" to (it.name ?: "Printer Bluetooth"))
                    })
                } catch (e: Exception) { result.error("bluetooth_unavailable", e.message, null) }
            }
            "selectPrinter" -> withPermission(result) {
                try {
                    val address = requireNotNull(call.argument<String>("address"))
                    val device = BluetoothTransport.device(this, address)
                    StateStore.select(this, address, device.name ?: "Printer Bluetooth")
                    result.success(null)
                } catch (e: Exception) { result.error("printer_unavailable", e.message, null) }
            }
            "forgetPrinter" -> {
                StateStore.forget(this, requireNotNull(call.argument("address")))
                result.success(null)
            }
            "setPreferences" -> {
                StateStore.preferences(this, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                result.success(null)
            }
            "clearRecords" -> { StateStore.clearRecords(this); result.success(null) }
            "openBluetoothSettings" -> { startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)); result.success(null) }
            "openPrintSettings" -> { startActivity(Intent(Settings.ACTION_PRINT_SETTINGS)); result.success(null) }
            "openExternalWebsite" -> {
                val url = requireNotNull(call.argument<String>("url"))
                try { startActivity(BrowserLauncher.intent(url)) }
                catch (e: android.content.ActivityNotFoundException) {
                    result.error("browser_unavailable", "Tidak ada browser yang dapat membuka alamat ini.", null)
                    return
                }
                result.success(null)
            }
            "printText" -> withPermission(result) { printText(call, result) }
            else -> result.notImplemented()
        }
    }

    private fun withPermission(result: MethodChannel.Result, action: () -> Unit) {
        if (BluetoothTransport.permitted(this)) { action(); return }
        if (pendingPermission != null) {
            result.error("permission_pending", "Permintaan izin sedang berlangsung. Coba kembali.", null)
            return
        }
        pendingPermission = action
        permissionResult = result
        if (Build.VERSION.SDK_INT >= 31) requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 101)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 101) return
        val action = pendingPermission
        val result = permissionResult
        pendingPermission = null
        permissionResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) action?.invoke()
        else result?.error("permission_denied", "Izin perangkat terdekat diperlukan. Izinkan Bluetooth melalui pengaturan izin aplikasi.", null)
    }

    @SuppressLint("MissingPermission")
    private fun printText(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        if (address == null) { result.error("no_printer", "Pilih printer terlebih dahulu.", null); return }
        val text = call.argument<String>("text").orEmpty()
        val paper = call.argument<Int>("paperMm") ?: 58
        val copies = call.argument<Int>("copies") ?: 1
        if (text.isBlank() || text.length > 12000 || copies !in 1..5 || paper !in listOf(58, 80)) {
            result.error("invalid_job", "Periksa teks, kertas, dan jumlah salinan (1–5).", null)
            return
        }
        val title = call.argument<String>("title") ?: "Cetak teks"
        val context = applicationContext
        BluetoothTransport.queue.execute {
            var name = address
            try {
                name = BluetoothTransport.device(context, address).name ?: address
                val control = JobControl()
                BluetoothTransport.send(context, address, control) { output ->
                    repeat(copies) {
                        EscPos.text(text, paper, output, control)
                        EscPos.finish(output, StateStore.cut(context))
                    }
                }
                StateStore.select(context, address, name, used = true)
                StateStore.record(context, title, name, paper, "sent")
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                StateStore.record(context, title, name, paper, "failed", e.message)
                runOnUiThread { result.error("print_failed", e.message, null) }
            }
        }
    }
}

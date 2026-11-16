package com.example.print_service

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/** One store shared by Flutter and Android's print service, in the same process. */
object StateStore {
    private fun prefs(context: Context) = context.getSharedPreferences("print_service", Context.MODE_PRIVATE)
    private fun array(context: Context, key: String): JSONArray =
        runCatching { JSONArray(prefs(context).getString(key, "[]")) }.getOrDefault(JSONArray())

    private fun now(): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date())

    @Synchronized fun snapshot(context: Context): Map<String, Any?> {
        val p = prefs(context)
        return mapOf(
            "paperMm" to p.getInt("paperMm", 58),
            "cutPaper" to p.getBoolean("cutPaper", false),
            "website" to p.getString("website", "").orEmpty().let {
                if (it.startsWith("https://appassets.androidplatform.net/")) "" else it
            },
            "selectedAddress" to p.getString("selectedAddress", null),
            "printers" to array(context, "printers").asMaps(),
            "records" to array(context, "records").asMaps(),
        )
    }

    @Synchronized fun preferences(context: Context, values: Map<*, *>) {
        val editor = prefs(context).edit()
        (values["paperMm"] as? Number)?.toInt()?.let {
            require(it == 58 || it == 80) { "Ukuran kertas harus 58 atau 80 mm." }
            editor.putInt("paperMm", it)
        }
        (values["cutPaper"] as? Boolean)?.let { editor.putBoolean("cutPaper", it) }
        (values["website"] as? String)?.let { editor.putString("website", it) }
        editor.apply()
    }

    @Synchronized fun select(context: Context, address: String, name: String, used: Boolean = false) {
        val existing = array(context, "printers").asMaps()
        val previous = existing.find { it["address"] == address }
        val printer = JSONObject().put("address", address).put("name", name)
        val lastUsed = if (used) now() else previous?.get("lastUsed")
        if (lastUsed != null) printer.put("lastUsed", lastUsed)
        val printers = JSONArray().put(printer)
        existing.filter { it["address"] != address }.take(29).forEach { printers.put(JSONObject(it)) }
        prefs(context).edit().putString("printers", printers.toString())
            .putString("selectedAddress", address).apply()
    }

    @Synchronized fun forget(context: Context, address: String) {
        val printers = JSONArray()
        array(context, "printers").asMaps().filter { it["address"] != address }.forEach { printers.put(JSONObject(it)) }
        val editor = prefs(context).edit().putString("printers", printers.toString())
        if (prefs(context).getString("selectedAddress", null) == address) editor.remove("selectedAddress")
        editor.apply()
    }

    @Synchronized fun record(context: Context, title: String, printer: String, paper: Int, status: String, error: String? = null) {
        val record = JSONObject().put("id", UUID.randomUUID().toString())
            .put("title", title.take(160)).put("printer", printer).put("paperMm", paper)
            .put("status", status).put("time", now())
        if (error != null) record.put("error", error.take(300))
        val records = JSONArray().put(record)
        array(context, "records").asMaps().take(99).forEach { records.put(JSONObject(it)) }
        prefs(context).edit().putString("records", records.toString()).apply()
    }

    @Synchronized fun clearRecords(context: Context) {
        prefs(context).edit().remove("records").apply()
    }

    fun paper(context: Context) = prefs(context).getInt("paperMm", 58)
    fun cut(context: Context) = prefs(context).getBoolean("cutPaper", false)
    @Synchronized fun printerAddresses(context: Context): Set<String> =
        array(context, "printers").asMaps().mapNotNull { it["address"] as? String }.toSet()

    private fun JSONArray.asMaps(): List<Map<String, Any?>> = (0 until length()).map { index ->
        val item = getJSONObject(index)
        item.keys().asSequence().associateWith { key -> item.get(key).let { if (it == JSONObject.NULL) null else it } }
    }
}

package com.darkdev.ledgerlock

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity: biometric_storage needs it.
 * "ledgerlock/files" channel: opens the system document picker and returns the chosen file's bytes
 * straight from its content URI, so no plaintext copy is ever written into the app's storage
 * (file_picker would cache one). The Dart side encrypts the bytes before anything touches disk.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingSave: Pair<MethodChannel.Result, ByteArray>? = null
    private var pendingPerm: MethodChannel.Result? = null

    private val requestPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingPerm?.success(granted)
        pendingPerm = null
    }

    // "Save as" via the system picker: the user chooses where the (plaintext) export goes; nothing is
    // written into app storage first.
    private val createCsv = registerForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { onSaveTarget(it) }
    private val createPdf = registerForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { onSaveTarget(it) }

    private fun onSaveTarget(uri: Uri?) {
        val (result, bytes) = pendingSave ?: return
        pendingSave = null
        if (uri == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("no stream")
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("write_failed", e.message, null) }
            }
        }.start()
    }
    private val maxBytes = 30L * 1024 * 1024

    private val openDocument = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        val result = pending ?: return@registerForActivityResult
        pending = null
        if (uri == null) {
            result.success(null)
            return@registerForActivityResult
        }
        Thread {
            try {
                var name = "document"
                var size = -1L
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val s = c.getColumnIndex(OpenableColumns.SIZE)
                        if (n >= 0) name = c.getString(n) ?: name
                        if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                    }
                }
                if (size > maxBytes) {
                    runOnUiThread { result.error("too_large", "File is larger than 30 MB", null) }
                    return@Thread
                }
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                runOnUiThread {
                    if (bytes == null) result.error("unreadable", "Could not read the file", null)
                    else result.success(mapOf("name" to name, "mime" to mime, "bytes" to bytes))
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("unreadable", e.message, null) }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ledgerlock/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    if (pending != null) {
                        result.error("busy", "A picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pending = result
                    @Suppress("UNCHECKED_CAST")
                    val types = (call.argument<List<String>>("mimeTypes") ?: listOf("*/*")).toTypedArray()
                    openDocument.launch(types)
                }
                "save" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "export.csv"
                    if (bytes == null || pendingSave != null || pending != null) {
                        result.error("busy", "A picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pendingSave = result to bytes
                    if (call.argument<String>("mime") == "application/pdf") createPdf.launch(name) else createCsv.launch(name)
                }
                "requestNotifications" -> {
                    if (android.os.Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                        android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (pendingPerm != null) {
                        result.error("busy", "Already asking", null)
                    } else {
                        pendingPerm = result
                        requestPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                    }
                }
                "scheduleReminders" -> {
                    @Suppress("UNCHECKED_CAST")
                    val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                    Reminders.ensureChannel(this)
                    Reminders.scheduleAll(this, items)
                    result.success(true)
                }
                "cancelReminders" -> {
                    Reminders.cancelAll(this)
                    result.success(true)
                }
                "openUrl" -> {
                    // Hands an https link to the user's browser. This app has no INTERNET permission and
                    // never connects; the browser does, only after the user taps (SPEC §2.12).
                    val uri = call.argument<String>("url")?.let(Uri::parse)
                    if (uri == null || uri.scheme != "https" || uri.host.isNullOrEmpty() || uri.query != null) {
                        result.error("bad_url", "Only plain https links", null)
                        return@setMethodCallHandler
                    }
                    try {
                        // Neutral referrer: don't let the browser tell the site the visit came from this app.
                        val view = Intent(Intent.ACTION_VIEW, uri)
                            .addCategory(Intent.CATEGORY_BROWSABLE)
                            .putExtra(Intent.EXTRA_REFERRER, Uri.parse("android-app://android"))
                        startActivity(view)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.error("no_browser", "No browser installed", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

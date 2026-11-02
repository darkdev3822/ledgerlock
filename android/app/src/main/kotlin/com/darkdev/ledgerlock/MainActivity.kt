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

    // ---- Encrypted backups (M9): stream files in/out without loading them into memory ----
    private var pendingBackupOut: Pair<MethodChannel.Result, String>? = null // result, source path
    private var pendingBackupIn: Pair<MethodChannel.Result, String>? = null // result, destination path
    private val backupMaxBytes = 8L * 1024 * 1024 * 1024

    private val createBackupDoc = registerForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri: Uri? ->
        val (result, src) = pendingBackupOut ?: return@registerForActivityResult
        pendingBackupOut = null
        if (uri == null) { result.success(false); return@registerForActivityResult }
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { out -> java.io.File(src).inputStream().use { it.copyTo(out, 1 shl 16) } }
                    ?: throw IllegalStateException("no stream")
                runOnUiThread { result.success(true) }
            } catch (e: Throwable) {
                runOnUiThread { result.error("write_failed", e.message, null) }
            }
        }.start()
    }

    private val openBackupDoc = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        val (result, dest) = pendingBackupIn ?: return@registerForActivityResult
        pendingBackupIn = null
        if (uri == null) { result.success(false); return@registerForActivityResult }
        Thread {
            val target = java.io.File(dest)
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { out ->
                        val buf = ByteArray(1 shl 16)
                        var total = 0L
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            total += n
                            if (total > backupMaxBytes) throw IllegalStateException("too large")
                            out.write(buf, 0, n)
                        }
                    }
                } ?: throw IllegalStateException("unreadable")
                runOnUiThread { result.success(true) }
            } catch (e: Throwable) {
                target.delete()
                runOnUiThread { result.error("unreadable", e.message, null) }
            }
        }.start()
    }

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
            } catch (e: Throwable) {
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
                        if (n >= 0) name = cleanName(c.getString(n)) ?: name
                        if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                    }
                }
                if (size > maxBytes) {
                    runOnUiThread { result.error("too_large", "File is larger than 30 MB", null) }
                    return@Thread
                }
                // Don't trust the provider's SIZE: read at most maxBytes + 1 (T21).
                val bytes = contentResolver.openInputStream(uri)?.use { readCapped(it) }
                if (bytes != null && bytes.size > maxBytes) {
                    runOnUiThread { result.error("too_large", "File is larger than 30 MB", null) }
                    return@Thread
                }
                val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                runOnUiThread {
                    if (bytes == null) result.error("unreadable", "Could not read the file", null)
                    else result.success(mapOf("name" to name, "mime" to mime, "bytes" to bytes))
                }
            } catch (e: Throwable) { // includes OutOfMemoryError: never crash on a hostile file
                runOnUiThread { result.error("unreadable", e.message, null) }
            }
        }.start()
    }

    private fun readCapped(input: java.io.InputStream): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val n = input.read(buf)
            if (n < 0) break
            total += n
            out.write(buf, 0, n)
            if (total > maxBytes) break
        }
        return out.toByteArray()
    }

    /** Display names come from other apps: cap length, drop control and bidi-override characters (T21). */
    private fun cleanName(raw: String?): String? {
        if (raw == null) return null
        val cleaned = raw.filter { ch ->
            !Character.isISOControl(ch) && ch !in '\u202A'..'\u202E' && ch !in '\u2066'..'\u2069' && ch != '\u200E' && ch != '\u200F'
        }.trim()
        return cleaned.take(120).ifEmpty { null }
    }

    private val linkHosts = setOf("irs.gov", "score.org")

    /** Same rules as Dart's isAllowedLink, enforced again here (T8, T21). */
    private fun allowedLink(uri: Uri): Boolean {
        val host = uri.host ?: return false
        if (uri.scheme != "https" || uri.query != null || uri.fragment != null || uri.userInfo != null || uri.port != -1) return false
        if (!Regex("^[a-z0-9.-]+$").matches(host)) return false
        return linkHosts.any { host == it || host.endsWith(".$it") }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setSecure(true) // T22: from the first frame, before any unlock
    }

    /** Blocks screenshots, screen recording and the app-switcher thumbnail (T22). Default on. */
    private fun setSecure(on: Boolean) {
        if (on) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        if (android.os.Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(!on)
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
                "ocr" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.size > maxBytes) {
                        result.error("bad_input", "No image or too large", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val text = Ocr.recognize(applicationContext, bytes)
                            runOnUiThread { result.success(text) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("ocr_failed", e.message, null) }
                        }
                    }.start()
                }
                "cancelReminders" -> {
                    Reminders.cancelAll(this)
                    result.success(true)
                }
                "setSecure" -> {
                    setSecure(call.argument<Boolean>("on") != false)
                    result.success(null)
                }
                "saveBackup" -> {
                    val src = call.argument<String>("path")
                    val name = call.argument<String>("name") ?: "ledgerlock.llbackup"
                    // Only files the app itself staged inside its own storage.
                    if (src == null || !java.io.File(src).canonicalPath.startsWith(filesDir.parentFile!!.canonicalPath + java.io.File.separator) || pendingBackupOut != null) {
                        result.error("bad_input", "No backup to save", null)
                        return@setMethodCallHandler
                    }
                    pendingBackupOut = result to src
                    createBackupDoc.launch(name)
                }
                "pickBackup" -> {
                    val dest = call.argument<String>("dest")
                    if (dest == null || !java.io.File(dest).canonicalPath.startsWith(filesDir.parentFile!!.canonicalPath + java.io.File.separator) || pendingBackupIn != null) {
                        result.error("bad_input", "Bad destination", null)
                        return@setMethodCallHandler
                    }
                    pendingBackupIn = result to dest
                    openBackupDoc.launch(arrayOf("*/*"))
                }
                "openUrl" -> {
                    // Hands an https link to the user's browser. This app has no INTERNET permission and
                    // never connects; the browser does, only after the user taps (SPEC §2.12).
                    val uri = call.argument<String>("url")?.let(Uri::parse)
                    if (uri == null || !allowedLink(uri)) {
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

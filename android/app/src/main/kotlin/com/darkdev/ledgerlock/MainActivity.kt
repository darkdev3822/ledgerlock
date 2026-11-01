package com.darkdev.ledgerlock

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
                else -> result.notImplemented()
            }
        }
    }
}

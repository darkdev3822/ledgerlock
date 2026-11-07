package com.darkdev.ledgerlock

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns

/**
 * One pending "launch action" from outside the app: a home-screen shortcut, the Quick Settings tile, or a file shared
 * from another app. Held in memory only (never written to disk); the Dart side takes it once the app is ready and
 * asks the user before anything enters the vault (SECURITY.md T44).
 */
object LaunchInbox {
    const val MAX_BYTES = 30L * 1024 * 1024
    val KINDS = setOf("expense", "income", "scan", "trip")

    @Volatile private var item: Map<String, Any?>? = null

    @Synchronized fun put(m: Map<String, Any?>) { item = m }
    @Synchronized fun take(): Map<String, Any?>? = item.also { item = null }
    fun has() = item != null

    /** Reads a shared content:// file, capped, with a cleaned display name. Never throws. */
    fun readShared(ctx: Context, uri: Uri, fallbackMime: String?): Map<String, Any?> {
        // content:// only (file:// could point into this app's own private storage), and never our own providers.
        if (uri.scheme != "content" || uri.authority.orEmpty().startsWith(ctx.packageName)) {
            return mapOf("kind" to "share_error", "why" to "unsupported")
        }
        return try {
            var name: String? = null
            var size = -1L
            ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0) name = cleanName(c.getString(n))
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
            if (size > MAX_BYTES) return mapOf("kind" to "share_error", "why" to "too_large")
            val bytes = ctx.contentResolver.openInputStream(uri)?.use { readCapped(it) }
                ?: return mapOf("kind" to "share_error", "why" to "unreadable")
            if (bytes.size > MAX_BYTES) return mapOf("kind" to "share_error", "why" to "too_large")
            mapOf(
                "kind" to "share",
                "name" to name,
                "mime" to (ctx.contentResolver.getType(uri) ?: fallbackMime),
                "bytes" to bytes,
            )
        } catch (e: Throwable) { // incl. SecurityException / OutOfMemoryError: never crash on a hostile share
            mapOf("kind" to "share_error", "why" to "unreadable")
        }
    }

    /** Reads at most MAX_BYTES + 1 (a provider's SIZE can lie, T21). */
    fun readCapped(input: java.io.InputStream): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val n = input.read(buf)
            if (n < 0) break
            total += n
            out.write(buf, 0, n)
            if (total > MAX_BYTES) break
        }
        return out.toByteArray()
    }

    /** Display names come from other apps: cap length, drop control and bidi-override characters (T21). */
    fun cleanName(raw: String?): String? {
        if (raw == null) return null
        val cleaned = raw.filter { ch ->
            !Character.isISOControl(ch) && ch !in '‪'..'‮' && ch !in '⁦'..'⁩' && ch != '‎' && ch != '‏'
        }.trim()
        return cleaned.take(120).ifEmpty { null }
    }
}

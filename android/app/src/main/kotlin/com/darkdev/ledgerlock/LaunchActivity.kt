package com.darkdev.ledgerlock

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle

/**
 * Invisible trampoline for the share sheet ("Share > LedgerLock"), home-screen shortcuts and the Quick Settings tile.
 * It records what was asked in [LaunchInbox] and brings the single app task to the front the way the launcher does,
 * so there is never a second copy of the app inside another app's task. Shows nothing and keeps nothing on disk.
 */
class LaunchActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val i = intent
        if (i?.action == Intent.ACTION_SEND) {
            val uri = streamOf(i)
            if (uri == null) {
                LaunchInbox.put(mapOf("kind" to "share_error", "why" to "unsupported"))
                openApp()
                return
            }
            // Off the main thread: up to 30 MB from another app's provider.
            Thread {
                val m = LaunchInbox.readShared(applicationContext, uri, i.type)
                runOnUiThread {
                    LaunchInbox.put(m)
                    openApp()
                }
            }.start()
            return
        }
        val kind = i?.action?.substringAfterLast('.')?.lowercase()
        if (kind != null && kind in LaunchInbox.KINDS) LaunchInbox.put(mapOf("kind" to kind))
        openApp()
    }

    private fun streamOf(i: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_STREAM)

    private fun openApp() {
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
        )
        finish()
    }
}

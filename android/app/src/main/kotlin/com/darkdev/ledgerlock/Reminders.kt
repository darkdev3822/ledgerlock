package com.darkdev.ledgerlock

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local reminders with no third-party code (SPEC §2.6, §2.13): AlarmManager + NotificationManager.
 * The schedule is computed in Dart. Only generic text is stored/shown here ("Time for a quick check-in"),
 * never amounts or payees, because these prefs and the lock screen are outside the encrypted vault.
 */
object Reminders {
    private const val PREFS = "ll_reminders"
    private const val KEY = "schedule"
    const val CHANNEL = "reminders"

    private fun alarmIntent(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
            .setAction("com.darkdev.ledgerlock.REMIND")
            .putExtra("id", id).putExtra("title", title).putExtra("body", body)
        return PendingIntent.getBroadcast(ctx, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** Replaces the whole schedule. items: [{id, at (epoch ms), title, body}]. */
    fun scheduleAll(ctx: Context, items: List<Map<String, Any?>>) {
        cancelAll(ctx)
        val arr = JSONArray()
        for (m in items) {
            arr.put(JSONObject().put("id", (m["id"] as Number).toInt()).put("at", (m["at"] as Number).toLong())
                .put("title", m["title"] as String).put("body", m["body"] as String))
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
        arm(ctx, arr)
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val arr = load(ctx)
        for (k in 0 until arr.length()) {
            val o = arr.getJSONObject(k)
            am.cancel(alarmIntent(ctx, o.getInt("id"), o.getString("title"), o.getString("body")))
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }

    /** After a reboot or app update, alarms are gone: set the future ones again. */
    fun rearm(ctx: Context) = arm(ctx, load(ctx))

    private fun load(ctx: Context): JSONArray =
        try { JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]")) } catch (e: Exception) { JSONArray() }

    private fun arm(ctx: Context, arr: JSONArray) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val now = System.currentTimeMillis()
        for (k in 0 until arr.length()) {
            val o = arr.getJSONObject(k)
            val at = o.getLong("at")
            if (at <= now) continue
            // Inexact is fine for reminders and needs no exact-alarm permission.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent(ctx, o.getInt("id"), o.getString("title"), o.getString("body")))
        }
    }

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Quarterly tax dates and check-ins"
            })
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminders.rearm(ctx)
            "com.darkdev.ledgerlock.REMIND" -> show(ctx, intent)
        }
    }

    private fun show(ctx: Context, intent: Intent) {
        Reminders.ensureChannel(ctx)
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) android.app.Notification.Builder(ctx, Reminders.CHANNEL)
        else @Suppress("DEPRECATION") android.app.Notification.Builder(ctx)
        val n = b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(intent.getStringExtra("title") ?: "LedgerLock")
            .setContentText(intent.getStringExtra("body") ?: "")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        nm.notify(intent.getIntExtra("id", 0), n)
    }
}
